tag 'dg-service-<%= @app_standard_name %>-server'
directory ENV['PUMA_DIRECTORY'] if ENV.key?('PUMA_DIRECTORY')
threads ENV.fetch('PUMA_MIN_THREADS', 4).to_i, ENV.fetch('PUMA_MAX_THREADS', 4).to_i
bind "tcp://0.0.0.0:#{ENV.fetch('PUMA_PORT', <%= @app_port || '8080' %>)}"
environment ENV.fetch('UNITY_ENV') { 'development' }
stdout_redirect ENV['PUMA_LOG_FILE'], ENV['PUMA_LOG_FILE'] if ENV.key?('PUMA_LOG_FILE')
workers ENV.fetch('PUMA_WORKERS').to_i if ENV.key?('PUMA_WORKERS')
persistent_timeout 60
queue_requests ENV.fetch('UNITY_ENV', 'development') == 'development'
prune_bundler
drain_on_shutdown true
