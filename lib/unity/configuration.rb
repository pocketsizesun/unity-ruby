# frozen_string_literal: true

module Unity
  class Configuration
    def self.default_options
      {
        autoload_paths: %w[lib],
        auth_namespace: nil,
        time_zone: 'UTC',
        concurrency: ENV.fetch('UNITY_CONCURRENCY', 4).to_i,
        auth_connection_timeout: 5,
        auth_enabled: true,
        auth_endpoint: nil,
        log_level: Logger::INFO,
        event_emitter_enabled: true,
        middlewares: []
      }
    end

    def initialize(options = {})
      @options = self.class.default_options.merge(options)
    end

    def max_threads
      concurrency
    end

    def max_threads=(arg)
      self[:concurrency] = arg.to_i
    end

    def [](key)
      @options[key.to_sym]
    end

    def []=(key, value)
      @options[key.to_sym] = value
    end

    def method_missing(method_name, *args, &block)
      method_name_str = method_name.to_s
      if method_name_str.include?('=')
        self[method_name_str.slice(0, method_name_str.length - 1)] = args.first
      else
        @options[method_name]
      end
    end

    def respond_to_missing?(method_name, include_private = false)
      @options.key?(method_name)
    end
  end
end
