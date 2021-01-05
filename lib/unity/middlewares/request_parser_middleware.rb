# frozen_string_literal: true

module Unity
  module Middlewares
    class RequestParserMiddleware
      def initialize(app)
        @app = app
      end

      # @param [Hash] env
      def call(env)
        env['rack.request'] = Rack::Request.new(env)
        env['unity.operation_name'] = env['rack.request'].params.fetch('Operation', nil)
        env['unity.operation_context'] = Unity::OperationContext.new
        env['unity.operation_input'] = parse_request_body(env['rack.request'])
        @app.call(env)
      rescue JSON::ParserError => e
        [
          500,
          { 'content-type' => 'application/json' },
          [
            { 'error' => "JSON parser error: #{e.message}" }.to_json
          ]
        ]
      end

      private

      # @param [Rack::Request] request
      # @return [Hash]
      def parse_request_body(request)
        body = request.body.read.to_s
        return {} if body.empty?

        JSON.parse(body)
      end
    end
  end
end
