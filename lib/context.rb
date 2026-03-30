# frozen_string_literal: true

require_relative 'context/errors'

# class Context это Go-подобный context для Ruby
class Context
  # singleton
  def self.background
    @background ||= new(cancelable: false)
  end

  # Создает отменяемый контекст с родителем
  # @param parent [Context] родительский контекст
  # @return [Array<Context, Proc>] массив [контекст, callable для отмены]
  # @example
  #   ctx, cancel = Context.with_cancel(Context.background)
  #   ctx.done?  # => false
  #   cancel.call
  #   ctx.done?  # => true
  #   ctx.err    # => :canceled
  def self.with_cancel(parent)
    ctx = new(parent: parent, cancelable: true)
    # Регистрируем контекст как ребенка родителя
    parent.send(:add_child, ctx) if parent.respond_to?(:add_child, true)
    cancel_proc = -> { ctx.cancel! }
    [ctx, cancel_proc]
  end

  # Создает контекст со значением (аналог context.WithValue в Go)
  # @param parent [Context] родительский контекст
  # @param key [Symbol, String] ключ для значения
  # @param value [Object] значение для сохранения
  # @return [Context] новый контекст с сохраненным значением
  # @example
  #   ctx = Context.with_value(Context.background, :user, "alice")
  #   ctx[:user]  # => "alice"
  def self.with_value(parent, key, value)
    # Создаем новый контекст с маленьким hash для одного значения
    new(parent: parent, values: { key => value }, cancelable: parent.instance_variable_get(:@cancelable))
  end

  # Создает контекст с timeout (аналог context.WithTimeout в Go)
  # @param parent [Context] родительский контекст
  # @param timeout [Numeric] timeout в секундах
  # @return [Array<Context, Proc>] массив [контекст, callable для отмены]
  # @example
  #   ctx, cancel = Context.with_timeout(Context.background, 2)
  #   ctx.done?  # => false
  #   sleep 3
  #   ctx.done?  # => true
  #   ctx.err    # => :deadline_exceeded
  def self.with_timeout(parent, timeout)
    # Вычисляем deadline используя монотонное время
    current_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    own_deadline = current_time + timeout

    # Выбираем минимальный deadline между своим и родительским
    parent_deadline = parent.instance_variable_get(:@deadline)
    final_deadline = if parent_deadline && parent_deadline < own_deadline
                       parent_deadline
                     else
                       own_deadline
                     end

    ctx = new(parent: parent, deadline: final_deadline, cancelable: true)

    # Регистрируем контекст как ребенка родителя
    parent.send(:add_child, ctx) if parent.respond_to?(:add_child, true)

    cancel_proc = -> { ctx.cancel! }

    [ctx, cancel_proc]
  end

  def initialize(parent: nil, values: {}, deadline: nil, cancelable: true)
    @parent = parent
    @values = values
    @deadline = deadline
    @cancelable = cancelable

    @canceled = false
    @cancel_reason = nil
    @err = nil

    @mutex = Mutex.new
    @children = []
  end

  # Проверяет завершен ли контекст
  # Для background (не cancelable) всегда возвращает false
  # Проверяет отмену, deadline и родительские контексты
  # Ленивая проверка deadline - автоматически отменяет если истекло
  def done?
    return false unless @cancelable

    @mutex.synchronize do
      return true if @canceled

      # Ленивая проверка deadline
      if deadline_exceeded?
        @canceled = true
        @cancel_reason = :deadline_exceeded
        @err = DeadlineExceededError.new('context deadline exceeded')

        # Отменяем детей
        @children.each { |child| child.cancel!(:deadline_exceeded) }
        @children.clear

        return true
      end

      return true if parent_done?

      false
    end
  end

  # Отменяет контекст
  # Для background (не cancelable) ничего не делает
  # Устанавливает @canceled = true и @err
  # Рекурсивно отменяет всех детей
  # Thread-safe с использованием Mutex
  # @param reason [Symbol] причина отмены (:canceled или :deadline_exceeded)
  def cancel!(reason = :canceled)
    return unless @cancelable

    @mutex.synchronize do
      return if @canceled

      @canceled = true
      @cancel_reason = reason

      # Устанавливаем соответствующую ошибку
      @err = case reason
             when :deadline_exceeded
               DeadlineExceededError.new('context deadline exceeded')
             else
               CanceledError.new('context canceled')
             end

      # Отменяем всех детей с той же причиной
      @children.each { |child| child.cancel!(reason) }
      @children.clear
    end
  end

  # Возвращает ошибку контекста
  # :canceled - если контекст отменен через cancel!
  # :deadline_exceeded - если deadline истек
  # nil - если контекст активен
  def err
    @mutex.synchronize do
      # Проверяем свою ошибку
      return @cancel_reason if @canceled

      # Проверяем родительскую ошибку
      parent_err = @parent&.err
      return parent_err if parent_err

      # Ленивая проверка deadline
      if deadline_exceeded?
        @canceled = true
        @cancel_reason = :deadline_exceeded
        @err = DeadlineExceededError.new('context deadline exceeded')

        # Отменяем детей
        @children.each { |child| child.cancel!(:deadline_exceeded) }
        @children.clear

        return :deadline_exceeded
      end

      nil
    end
  end

  # Получает значение по ключу из контекста
  # Сначала ищет в текущем узле, затем вверх по parent chain
  # @param key [Symbol, String] ключ для поиска
  # @return [Object, nil] значение или nil если ключ не найден
  # @example
  #   parent = Context.with_value(Context.background, :user, "alice")
  #   child = Context.with_value(parent, :request_id, "123")
  #   child[:user]        # => "alice" (из parent)
  #   child[:request_id]  # => "123" (из текущего узла)
  #   child[:unknown]     # => nil
  def [](key)
    # Сначала проверяем текущий узел
    return @values[key] if @values.key?(key)

    # Затем идем вверх по parent chain
    @parent&.[](key)
  end

  private

  # Добавляет дочерний контекст в список @children
  # Вызывается только если parent cancelable
  # При отмене родителя все дети автоматически отменяются
  # @param child [Context] дочерний контекст
  def add_child(child)
    return unless @cancelable

    @mutex.synchronize do
      @children << child unless @children.include?(child)
    end
  end

  # Проверяет, истек ли deadline
  def deadline_exceeded?
    return false unless @deadline

    current_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    current_time >= @deadline
  end

  # Проверяет, завершен ли родительский контекст
  def parent_done?
    @parent&.done? || false
  end
end
