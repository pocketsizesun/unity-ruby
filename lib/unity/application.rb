# frozen_string_literal: true

module Unity
  class Application
    attr_reader   :config, :initialized_at, :operations, :policies, :event_handlers
    attr_accessor :logger

    def self.inherited(base)
      Unity.app_class = base
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
      @authentication_client_pool = nil
      @config = OpenStruct.new(
        autoload_paths: ['lib'],
        auth_namespace: nil,
        time_zone: 'UTC',
        max_threads: 4,
        auth_connection_timeout: 5,
        auth_enabled: true,
        auth_endpoint: nil
      )
      @rack_app = nil
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

    def event_handler(name, klass)
      @event_handlers[name.to_s] = "#{klass}EventHandler".to_sym
    end

    def load!
      @operation_handlers = {}
      @policy_handlers = {}
      @event_handler_instances = {}

      # init time zone
      ENV['TZ'] = config.time_zone

      # init auth client pool
      if config.auth_enabled == true
        @authentication_client_pool = ConnectionPool.new(
          size: config.max_threads.to_i,
          timeout: config.auth_connection_timeout.to_i
        ) do
          Unity::Authentication::Client.new(config.auth_endpoint)
        end
      end

      config.autoload_paths.each do |path|
        Dir.glob("#{path}/**/*.rb").each do |file|
          require_relative "#{Dir.pwd}/#{file}"
          logger&.debug "load file: #{Dir.pwd}/#{file}"
        end
      end

      operations.each do |k, v|
        begin
          @operation_handlers[k] = @module.const_get(:Operations).const_get(v)
        rescue NameError
          raise "Operation class '#{v}' not found"
        end
      end

      policies.each do |k, v|
        @policy_handlers[k] = @module.const_get(:OperationPolicies).const_get(v)
      end

      event_handlers.each do |k, v|
        @event_handler_instances[k] = @module.const_get(:EventHandlers).const_get(v).new
      end

      @rack_app = build_rack_app
    end

    def find_operation(name)
      @operation_handlers[name.to_s]
    end

    def find_policy(name)
      @policy_handlers[name.to_s]
    end

    def find_event_handler(name)
      raise EventHandlerNotFound, name unless @event_handlers.key?(name)

      @event_handlers[name]
    end

    def call_event_handler(name, input)
      find_event_handler(name).call(input)
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
        if __self__.config.auth_enabled == true
          use Unity::Middlewares::AuthenticationMiddleware
        end

        run Unity::Middlewares::OperationExecutorMiddleware.new
      end.to_app
    end
  end
end
