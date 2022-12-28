# frozen_string_literal: true

module Unity
  class Configuration
    DEFAULT_CONCURRENCY = 4

    # @return [String]
    attr_accessor :time_zone

    # @return [Integer]
    attr_accessor :concurrency

    # @return [Integer]
    attr_accessor :log_level

    # @return [Array<String>]
    attr_accessor :middlewares

    # @return [Logger]
    attr_accessor :logger

    # @return [Array<String>]
    attr_accessor :autoload_paths

    # @return [Boolean]
    attr_accessor :cache_code

    # @return [Hash{String => Object}]
    attr_accessor :custom_values

    def initialize
      @time_zone = 'UTC'
      @concurrency = ENV.fetch('CONCURRENCY', DEFAULT_CONCURRENCY).to_i
      @log_level = ::Logger::INFO
      @middlewares = []
      @logger = ::Logger.new($stdout)
      @autoload_paths = []
      @eager_load = true
      @custom_values = {}
      @report_exception = true
      @cache_code = true
    end

    # @return [Integer]
    def max_threads
      concurrency
    end

    # @param arg [Integer]
    # @return [void]
    def max_threads=(arg)
      @concurrency = arg.to_i
    end

    # @return [Boolean]
    def eager_load?
      @eager_load == true
    end

    # @return [Boolean]
    def report_exception?
      @report_exception == true
    end

    # @return [Boolean]
    def cache_code?
      @cache_code == true
    end

    def set(key, value)
      @custom_values[key.to_sym] = value
    end

    def get(key)
      @custom_values[key.to_sym]
    end
  end
end
