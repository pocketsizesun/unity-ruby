# frozen_string_literal: true

module Unity
  class Application
    attr_reader   :booted_at, :operations, :routes
    attr_accessor :logger

    def self.inherited(base)
      inst = base.new
      base.instance_variable_set(:@instance, inst)
      Unity.app_class ||= base
      Unity.application ||= inst
    end

    def self.config
      @instance.config
    end

    def self.operation(name, klass_name = nil, &block)
      @instance.operation(name, klass_name, &block)
    end

    def self.app_name
      @instance.app_name
    end

    def self.app_name=(arg)
      @instance.app_name = arg
    end

    def self.route(path, handler = nil, &block)
      @instance.route(path, handler, &block)
    end

    def self.configure(&block)
      @instance.configure(&block)
    end

    def self.config_for(name)
      @instance.config_for(name)
    end

    def self.load!
      @instance.load!
    end

    def initialize
      @app_name = self.class.to_s
      @operations = {}
      @logger = ::Logger.new(STDOUT)
      @operations = {}
      @booted_at = Unity.current_timestamp
      @file_configurations = {}
      @routes = []
      @router_middleware = Unity::Middlewares::RouterMiddleware.new(self)
    end

    # @return [String]
    def app_name
      @app_name
    end

    # @param value [String] An application name
    def app_name=(value)
      @app_name = value
    end

    # @return [Unity::Configuration]
    def config
      @config ||= Unity::Configuration.new
    end

    def routes
      @routes
    end

    def logger
      @logger
    end

    def configure(&block)
      instance_eval(&block)
    end

    # @param name [String] An operation name
    # @return [Unity::Operation, NilClass]
    def find_operation(name)
      @operations[name.to_s]
    end

    # Add a route
    # @param path [String]
    # @param handler [Unity::RouteController, NilClass]
    def route(path, handler = nil, &block)
      @routes << Route.new(path, handler || block)
    end

    # @return [Integer]
    def uptime
      Process.clock_gettime(Process::CLOCK_REALTIME, :second).to_i - @booted_at
    end

    # Load a configuration from a YAML file located in "{app_root}/config/{name}.yml"
    # @param name [String] A configuration file name (without the extension)
    # @return [Object]
    def config_for(name)
      name = name.to_s
      return @file_configurations[name] if @file_configurations.key?(name)

      filename = "#{Unity.root}/config/#{name}.yml"
      unless File.exist?(filename)
        raise "Configuration file not found: #{filename}"
      end

      YAML.load(ERB.new(File.read(filename)).result(binding)).fetch(Unity.env)
    end

    def load_tasks
      Dir.glob("#{Unity.root}/lib/tasks/**/*.rake").each do |rake_file|
        load rake_file
      end
    end

    # @param tag [String]
    def silent(tag = '@', on: [StandardError], &_block)
      yield
    rescue *on => e
      Unity.logger&.error(
        'message' => "[#{tag}] silent exception: #{e.message} (#{e.class})",
        'backtrace' => e.backtrace
      )

      nil
    end

    # @param name [String] An operation name
    # @param klass_name [Unity::Operation] An operation class
    def operation(name, klass_name = nil, &block)
      @operations[name.to_s] = klass_name || block.call
    end

    def load!
      @operation_handlers = {}

      # init time zone
      ENV['TZ'] = config.time_zone

      # load specific environment config
      env_config_file = Unity.root + "/config/environments/#{Unity.env}.rb"
      if File.exist?(env_config_file)
        load env_config_file
      end

      # configure logger
      @logger = config.logger unless config.logger.nil?
      @logger&.level = config.log_level

      # run initializers
      Dir.glob("#{Unity.root}/config/initializers/*.rb").each do |item|
        file = File.basename(item)
        Unity.logger&.debug "load initializer file: #{file}"
        require "#{Unity.root}/config/initializers/#{file}"
      end
    end

    def call(env)
      @router_middleware.call(env)
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
