# frozen_string_literal: true

module Unity
  class OperationOutput
    def initialize(data = {})
      @data = data
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

    def to_json(*)
      Oj.dump(as_json, mode: :compat)
    end
  end
end
