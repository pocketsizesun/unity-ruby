# frozen_string_literal: true

module Unity
  class Application
    attr_reader   :booted_at, :operations, :routes
    attr_accessor :logger

    def self.inherited(base)
      Unity.app_class ||= base
    end

    def self.config
      @config ||= Unity::Configuration.new
    end

    def self.instance
      @instance ||= new
    end

    def self.load!
      instance.load!
    end

    def self.configure(&block)
      instance.configure(&block)
    end

    def self.operation(name, klass_name = nil, &block)
      instance.operation(name, klass_name, &block)
    end

    def self.find_operation(name)
      instance.find_operation(name)
    end

    def self.load_tasks
      instance.load_tasks
    end

    def self.name
      instance.name
    end

    def self.name=(arg)
      instance.name = arg
    end

    def self.route(path, handler = nil, &block)
      instance.route(path, handler, &block)
    end

    def self.config_for(*args)
      instance.config_for(*args)
    end

    def initialize
      @module = find_module
      @logger = ::Logger.new(STDOUT)
      @operations = {}
      @booted_at = Process.clock_gettime(Process::CLOCK_REALTIME, :second).to_i
      @file_configurations = {}
      @routes = []
      @router_middleware = Unity::Middlewares::RouterMiddleware.new(self)
    end

    def route(path, handler = nil, &block)
      @routes << Route.new(path, handler || block)
    end

    def find_module
      klass_split = self.class.to_s.split('::')
      klass_split.pop
      klass_split.reduce(Kernel) do |mod_klass, item|
        mod_klass.const_get(item.to_sym)
      end
    end

    def config
      self.class.config
    end

    def uptime
      Process.clock_gettime(Process::CLOCK_REALTIME, :second).to_i - @booted_at
    end

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

    def configure(&block)
      instance_exec(&block)
    end

    def silent(tag = '@', on: [StandardError], &_block)
      yield
    rescue *on => e
      Unity.logger&.error(
        'message' => "[#{tag}] silent exception: #{e.message} (#{e.class})",
        'backtrace' => e.backtrace
      )

      nil
    end

    def name=(arg)
      @name = arg.to_s
    end

    def name
      @name ||= @module.to_s.downcase
    end

    def operation(name, klass_name = nil, &block)
      name = name.to_s
      @operations[name] = klass_name || block || @module.const_get(:Operations).const_get("#{name}Operation".to_sym)
    rescue NameError
      raise StandardError, "Operation klass '#{@module.name}::Operations::#{name}Operation' not found"
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

    def find_operation(name)
      operations[name.to_s]
    end

    def call(env)
      # parse incoming request to {Rack::Request}
      request = Rack::Request.new(env)
      env['rack.request'] = request
      env['unity.operation_name'] = env['rack.request'].params.fetch('Operation', nil)
      env['unity.operation_context'] = Unity::OperationContext.new
      env['unity.operation_input'] = JSON.load(request.body) || {}

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
