# frozen_string_literal: true

require_relative 'context/errors'

# class Context это Go-подобный context для Ruby
class Context
  # singleton
  def self.background
    @background ||= new(cancelable: false)
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
  def cancel
    return unless @cancelable

    @mutex.synchronize do
      return if @canceled

      @canceled = true
      @err = CanceledError.new('context canceled')
      # Отменяем всех детей
      @children.each(&:cancel)
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

  private

  # Проверяет, истек ли deadline
  def deadline_exceeded?
    @deadline && Time.now >= @deadline
  end

  # Проверяет, завершен ли родительский контекст
  def parent_done?
    @parent&.done? || false
  end
end
