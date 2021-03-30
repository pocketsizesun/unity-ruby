# frozen_string_literal: true

module Unity
  class RecordHandler
    include Singleton

    def self.call(event)
      instance.call(event)
    end

    def call(event)
      raise "#call not implemented in #{self.class}"
    end
  end
end
