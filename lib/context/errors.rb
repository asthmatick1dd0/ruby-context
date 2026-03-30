# frozen_string_literal: true

class Context
  # базовая ошибка для всех context-related ошибок
  class Error < StandardError; end

  # ошибка отмены контекста
  class CanceledError < Error
    def initialize(msg = 'context canceled')
      super(msg)
    end
  end

  # ошибка превышения deadline
  class DeadlineExceededError < Error
    def initialize(msg = 'context deadline exceeded')
      super(msg)
    end
  end
end
