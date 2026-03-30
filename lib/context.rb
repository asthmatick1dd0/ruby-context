# frozen_string_literal: true

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

  # пока что моки для первой итерации
  # background никогда не завершён
  def done?
    false
  end

  # background никогда не содержит ошибок
  def err
    nil
  end
end
