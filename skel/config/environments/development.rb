# frozen_string_literal: true

Unity.application.configure do
  config.logger = Unity::Logger.new(STDOUT)
  config.logger.source = 'service-<%= @app_standard_name %>'
  config.log_level = Unity::Logger::DEBUG
end
