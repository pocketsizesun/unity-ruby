# frozen_string_literal: true

module Unity
  class OperationOutput
    def initialize(data)
      @data = data
    end

    def method_missing(method_name, *args, &block)
      return super unless @data.key?(method_name.name)

      @data.fetch(method_name.name, nil)
    end

    def respond_to_missing(method_name, include_private = false)
      @data.key?(method_name.name) || super
    end

    def [](key)
      @data[key.to_s]
    end

    def []=(key, value)
      @data[key.to_s] = value
    end

    def empty?
      @data.empty?
    end

    def as_json
      @data.as_json
    end

    def to_json(*args)
      Oj.dump(@data, mode: :compat)
    end
  end
end
