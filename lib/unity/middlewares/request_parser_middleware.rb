# frozen_string_literal: true

module Unity
  module Middlewares
    class RequestParserMiddleware
      JSON_PARSER_ERROR = '{"error":"JSON parser error"}'

      def initialize(app)
        @app = app
      end

      def call(env)
        env['rack.request'] = Rack::Request.new(env)
        env['unity.operation_name'] = env['rack.request'].params.fetch('Operation', nil)
        env['unity.operation_context'] = Unity::OperationContext.new
        env['unity.operation_input'] = parse_request_body(env['rack.request'])
        @app.call(env)
      rescue JSON::ParserError
        [500, { 'content-type' => 'application/json' }, [JSON_PARSER_ERROR]]
      end

      private

      def parse_request_body(request)
        JSON.parse(request.body.read)
      end
    end
  end
end
