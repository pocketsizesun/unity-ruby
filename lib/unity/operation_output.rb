# frozen_string_literal: true

module Unity
  class OperationOutput
    attr_accessor :code

    def initialize(data = {}, code = nil)
      @data = data
      @code = code
    end

    def [](key)
      @data[key.to_s]
    end

    def []=(key, value)
      @data[key.to_s] = value
    end

    def empty?
      @data.nil? || @data.empty?
    end

    def as_json
      @data&.as_json
    end

    def as_rack_response
      if !@data.nil? && !@data.empty?
        [
          @code || 200,
          { 'content-type' => 'application/json' },
          [JSON.dump(@data&.as_json)]
        ]
      else
        [@code || 204, { 'content-type' => 'application/json' }, []]
      end
    end
  end
end
