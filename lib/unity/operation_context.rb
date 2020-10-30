# frozen_string_literal: true

module Unity
  class OperationContext < Hash
    def initialize(data = {})
      data.each do |k, v|
        self[k] = v
      end
    end

    def []=(key, value)
      super(key.to_sym, value)
    end

    def [](key)
      super(key.to_sym)
    end

    def set(key, value)
      self[key] = value
    end
  end
end
