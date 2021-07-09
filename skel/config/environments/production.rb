# frozen_string_literal: true

Unity.application.configure do
  config.logger = Unity::Logger.new('log/app.log', 3, 100 * 1024 * 1024)
  config.logger.source = 'service-<%= @app_standard_name %>'
  config.log_level = Logger::WARN
end
