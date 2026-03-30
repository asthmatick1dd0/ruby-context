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

  def initialize(parent: nil, values: {}, deadline: nil, cancelable: true)
    @parent = parent
    @values = values
    @deadline = deadline
    @cancelable = cancelable

    @canceled = false
    @err = nil

    @mutex = Mutex.new
    @children = []
  end

  # Проверяет завершен ли контекст
  # Для background (не cancelable) всегда возвращает false
  # Проверяет отмену, deadline и родительские контексты
  def done?
    return false unless @cancelable

    @mutex.synchronize do
      return true if @canceled
      return true if deadline_exceeded?
      return true if parent_done?

      false
    end
  end

  # Отменяет контекст
  # Для background (не cancelable) ничего не делает
  # Устанавливает @canceled = true и @err = CanceledError
  # Рекурсивно отменяет всех детей
  # Thread-safe с использованием Mutex
  def cancel!
    return unless @cancelable

    @mutex.synchronize do
      return if @canceled

      @canceled = true
      @err = CanceledError.new('context canceled')
      # Отменяем всех детей
      @children.each(&:cancel!)
      @children.clear
    end
  end

  # Возвращает ошибку контекста
  # :canceled - если контекст или родитель отменен
  # :deadline_exceeded - если deadline истек (в будущем)
  # nil - если контекст активен
  def err
    @mutex.synchronize do
      return :canceled if @canceled
      return :canceled if @parent&.err == :canceled
      return :deadline_exceeded if deadline_exceeded?

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
    @deadline && Time.now >= @deadline
  end

  # Проверяет, завершен ли родительский контекст
  def parent_done?
    @parent&.done? || false
  end
end
