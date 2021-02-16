# frozen_string_literal: true

module Unity
  class Middleware
    def initialize(app, _options = {})
      @app = app
    end

    def call(env)
      raise "#call not implemented in #{self.class}"
    end
  end
end
