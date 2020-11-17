# frozen_string_literal: true

module Unity
  class OperationContext < Hash
    # @param data [Hash<String, Object>]
    def initialize(data = {})
      super()
      data.each do |k, v|
        self[k.to_s] = v
      end
    end

    # @param key [String]
    # @param value
    def []=(key, value)
      super(key.to_s, value)
    end

    # @param key [String]
    # @return A value
    def [](key)
      super(key.to_s)
    end

    # @param key [String]
    # @param value
    def set(key, value)
      self[key] = value
    end
  end
end
