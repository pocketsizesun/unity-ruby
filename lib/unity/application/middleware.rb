# frozen_string_literal: true

module Unity
  module Application
    class Middleware
      def initialize(app, options = {})
        @app = app
        @container = options.fetch(:container)
      end

      private

      def render_error(error, data = {}, code = 400)
        [
          code,
          { 'content-type' => 'application/json' },
          [JSON.dump({ 'error' => error, 'data' => data })]
        ]
      end
    end
  end
end
