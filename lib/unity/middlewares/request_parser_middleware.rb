# frozen_string_literal: true

module Unity
  module Middlewares
    class RequestParserMiddleware
      def initialize(app, options)
        @app = app
        @unity_app = options.fetch(:unity_app)
      end

      # @param [Hash] env
      def call(env)
        env['rack.request'] = Rack::Request.new(env)
        env['unity.operation_name'] = env['rack.request'].params.fetch('Operation', nil)
        env['unity.operation_context'] = Unity::OperationContext.new
        env['unity.operation_input'] = @unity_app.request_body_parser(env['rack.request'])
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
    end
  end
end
