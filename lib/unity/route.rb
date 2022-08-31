# frozen_string_literal: true

module Unity
  class Route
    attr_reader :path, :handler

    def initialize(path, handler)
      @path = path
      @handler = handler
    end

    def call(request)
      @handler.call(request)
    end

    def match?(tested_path)
      @path.match?(tested_path)
    end
  end
end
