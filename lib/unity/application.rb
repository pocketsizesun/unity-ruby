# frozen_string_literal: true

module Unity
  class Application
    attr_reader   :booted_at, :operations, :routes
    attr_accessor :logger

    def self.inherited(base)
      unless Unity.application.nil?
        raise RuntimeError, 'Only one Application is allowed'
      end

      inst = base.new
      base.instance_variable_set(:@instance, inst)
      Unity.application = inst
    end

    # @sg-ignore
    # @return [self]
    def self.instance
      @instance
    end

    # @sg-ignore
    # @return [void]
    def self.method_missing(method_name, *args, **kwargs, &block)
      instance.__send__(method_name, *args, **kwargs, &block)
    end

    # @param method_name [String]
    # @param include_private [Boolean]
    # @return [Boolean]
    def self.respond_to_missing?(method_name, include_private = false)
      instance.respond_to_missing?(method_name, include_private)
    end

    def initialize
      @app_name = self.class.to_s
      @operations = {}
      @logger = ::Logger.new($stdout)
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
    # @return [void]
    def app_name=(value)
      @app_name = value
    end

    # @return [Unity::Configuration]
    def config
      @config ||= Unity::Configuration.new
    end

    # @yieldparam [Unity::Configuration]
    # @return [void]
    def configure(&block)
      @config.instance_eval(&block)
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

      # configure zeitwerk
      @zeitwerk = Zeitwerk::Loader.new
      @zeitwerk.push_dir('lib') if File.directory?('lib')
      Dir.glob("#{Dir.pwd}/app/*").each do |dir|
        next unless File.directory?(dir)

        @zeitwerk.push_dir(dir)
        @logger&.debug("add autoload dir: #{dir}")
      end
      config.autoload_paths.each do |path|
        @zeitwerk.push_dir(path)

        @logger&.debug("add autoload dir: #{path}")
      end
      unless config.cache_code?
        require 'listen'

        listener = Listen.to(Dir.pwd) do |modified, added, removed|
          @operations = {}
          @zeitwerk.reload
          @zeitwerk.eager_load
          @logger&.debug "modified files: #{modified.join(', ')}"
          @logger&.debug "added files: #{added.join(', ')}"
          @logger&.debug "removed files: #{removed.join(', ')}"
        end

        listener.start

        @zeitwerk.enable_reloading
        @logger&.warn 'Code reloading enabled'
      end
      @zeitwerk.setup
      @zeitwerk.eager_load if config.eager_load?
    end

    def call(env)
      @router_middleware.call(env)
    end
  end
end
