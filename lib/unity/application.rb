# frozen_string_literal: true

module Unity
  class Application
    attr_reader   :config, :initialized_at, :operations, :policies, :event_handlers
    attr_accessor :logger

    def self.inherited(base)
      Unity.app_class ||= base
    end

    def self.instance
      @instance ||= new
    end

    def self.method_missing(method_name, *args, &block)
      instance.__send__(method_name, *args, &block)
    end

    def initialize
      @module = Kernel.const_get(self.class.to_s.split('::').first.to_sym)
      @logger = Unity::Logger.new(STDOUT)
      @operations = {}
      @policies = {}
      @event_handlers = {}
      @initialized_at = Time.now.to_i
      @config = Unity::Configuration.new
      @rack_app = nil
      @file_configurations = {}
    end

    def config_for(name)
      name = name.to_s
      return @file_configurations[name] if @file_configurations.key?(name)

      filename = "#{Unity.root}/config/#{name}.yml"
      unless File.exist?(filename)
        raise "Configuration file not found: #{filename}"
      end

      config_data = YAML.load(ERB.new(File.read(filename)).result(binding))
      @file_configurations[name] = \
        if config_data.is_a?(Hash)
          config_data.fetch(Unity.env)
        else
          {}
        end
    end

    def load_tasks
      Dir.glob("#{Unity.root}/lib/tasks/**/*.rake").each do |rake_file|
        load rake_file
      end
    end

    def configure(&block)
      instance_exec(&block)
    end

    def name=(arg)
      @name = arg.to_s
    end

    def name
      @name ||= @module.to_s.downcase
    end

    def operation(name, klass_name = nil)
      name = name.to_s
      @operations[name] = klass_name || "#{name}Operation".to_sym
    end

    def policy(name, klass_name = nil)
      name = name.to_s
      @policies[name] = klass_name || "#{name}OperationPolicy".to_sym
    end

    def event_handler(name, klass = nil, &block)
      @event_handlers[name.to_s] ||= []
      @event_handlers[name.to_s].push(
        !block.nil? ? block : "#{klass}EventHandler".to_sym
      )
    end

    def load!
      @operation_handlers = {}
      @policy_handlers = {}
      @event_handler_instances = {}

      # init time zone
      ENV['TZ'] = config.time_zone

      # load specific environment config
      env_config_file = Unity.root + "/config/environments/#{Unity.env}.rb"
      if File.exist?(env_config_file)
        load env_config_file
        @logger = config.logger unless config.logger.nil?
        @logger&.level = config.log_level
        logger&.info "load environment config from #{env_config_file}"
      end

      config.autoload_paths.each do |path|
        Dir.glob("#{path}/**/*.rb").each do |file|
          require_relative "#{Dir.pwd}/#{file}"
          logger&.debug "load file: #{Dir.pwd}/#{file}"
        end
      end

      operations.each do |k, v|
        @operation_handlers[k] = @module.const_get(:Operations).const_get(v)
      rescue NameError
        raise "Operation class '#{v}' not found"
      end

      policies.each do |k, v|
        @policy_handlers[k] = @module.const_get(:OperationPolicies).const_get(v)
      end

      event_handlers.each do |name, handlers|
        @event_handler_instances[name] = handlers.map do |v|
          if v.is_a?(Proc)
            v.call
          else
            @module.const_get(:EventHandlers).const_get(v)
          end
        end
      end

      # event worker
      unless config.event_worker_queue.nil?
        Unity::EventWorker.queue = config.event_worker_queue
      end

      # run initializers
      Dir.glob("#{Unity.root}/config/initializers/*.rb").each do |item|
        file = File.basename(item)
        Unity.logger&.debug "load initializer file: #{file}"
        require "#{Unity.root}/config/initializers/#{file}"
      end

      # Configure Shoryuken defaults
      # - change Shoryuken logger
      # - cache visibility timeout by default
      if defined?(Shoryuken)
        Shoryuken::Logging.logger = logger || Logger.new('/dev/null')
        Shoryuken.cache_visibility_timeout = true
      end

      # build rack app
      @rack_app = build_rack_app
    end

    def find_operation(name)
      @operation_handlers[name.to_s]
    end

    def find_policy(name)
      @policy_handlers[name.to_s]
    end

    def find_event_handlers(name)
      return nil unless @event_handler_instances.key?(name)

      @event_handler_instances[name]
    end

    def call(env)
      @rack_app.call(env)
    end

    private

    def render_error(error, data = {}, code = 400)
      [
        code,
        { 'content-type' => 'application/json' },
        [JSON.dump({ 'error' => error, 'data' => data })]
      ]
    end

    def parse_request_body(request)
      JSON.parse(request.body.read)
    end

    def build_rack_app
      __self__ = self

      Rack::Builder.new do
        map '/_status' do
          run Unity::Middlewares::HealthCheckMiddleware.new
        end

        use Unity::Middlewares::RequestParserMiddleware

        __self__.config.middlewares.each do |middleware|
          use middleware, app: __self__
        end

        run Unity::Middlewares::OperationExecutorMiddleware.new
      end.to_app
    end
  end
end
