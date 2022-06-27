# frozen_string_literal: true

module Unity
  class OperationContext
    # @param data [Hash<String, Object>]
    def initialize(data = {})
      @hash = {}
      data.each { |k, v| @hash[k.to_s] = v }
    end

    # @param key [String]
    # @param value
    def []=(key, value)
      @hash[key.to_s] = value
    end

    # @param key [String]
    # @return A value
    def [](key)
      @hash[key.to_s]
    end

    # @param key [String]
    # @param value
    def set(key, value)
      @hash[key] = value
    end

    def each(&block)
      @hash.each(&block)
    end

    def keys
      @hash.keys
    end

    def as_json(*)
      @hash.as_json
    end

    def to_json(*)
      as_json.to_json
    end
  end
end
