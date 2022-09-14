# frozen_string_literal: true

module Unity
  class RouteController
    def self.call(request)
      new.call(request)
    end

    # @param request [Rack::Request] A Rack request object
    # @return [Rack::Response]
    def call(request)
      raise "#call must be implemented in #{self.class}"
    end

    private

    def respond_with_text(text, status: 200, headers: {})
      [status, headers, [text]]
    end

    def respond_with_json(data, status: 200, headers: {})
      [status, { 'Content-Type' => 'application/json' }.merge!(headers), [JSON.fast_generate(data)]]
    end

    def head(status)
      [status, {}, []]
    end
  end
end
