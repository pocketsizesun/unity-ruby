# frozen_string_literal: true

require '<%= @app_name %>'

module <%= @app_module_name %>
  class Application < Unity::Application
    config.auth_enabled = false
    config.event_worker_queue = 'dg-service-<%= @app_standard_name %>-events'

    # operations
    operation :Test
  end
end
