# frozen_string_literal: true

module Unity
  class Application
    attr_reader   :config, :initialized_at, :operations, :policies
    attr_accessor :logger

    JSON_PARSER_ERROR = '{"error":"JSON parser error"}'

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

    def load!
      @operation_handlers = {}
      @policy_handlers = {}

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
    end

    def find_operation(name)
      @operation_handlers[name.to_s]
    end

    def find_policy(name)
      @policy_handlers[name.to_s]
    end

    def call(env)
      request = Rack::Request.new(env)
      if request.path == '/_status'
        return [
          200,
          { 'content-type' => 'application/json' },
          ["{\"uptime\":#{get_current_time - initialized_at}}"]
        ]
      end

      operation_name = request.params.fetch('Operation', nil)
      operation_handler = find_operation(operation_name)
      return render_error('Operation not found') if operation_handler.nil?

      operation_input = parse_request_body(request)
      operation_context = Unity::OperationContext.new

      if config.auth_enabled == true
        policy_handler = find_policy(operation_name)
        unless policy_handler.nil?
          policy = policy_handler.new(operation_context)
          policy.call(operation_input)
        end

        if operation_context.fetch(:auth_enabled, true) == true
          auth_result = @authentication_client_pool.with do |client|
            client.authenticate(
              request.get_header('HTTP_AUTHORIZATION'),
              "#{@auth_namespace}:#{operation_name}",
              resource: operation_context.fetch(:auth_resource, nil),
              conditions: operation_context.fetch(:auth_conditions, nil)
            )
          end

          operation_context.set(:auth_result, auth_result)
        end
      end

      operation = operation_handler.new(operation_context)

      [
        200,
        { 'content-type' => 'application/json' },
        [operation.call(operation_input).to_json]
      ]
    rescue Simdjson::ParseError
      [500, { 'content-type' => 'application/json' }, [JSON_PARSER_ERROR]]
    rescue Unity::Authentication::Error => e
      [e.code, { 'content-type' => 'application/json' }, [e.as_json.to_json]]
    rescue Unity::Operation::OperationError => e
      logger&.error(
        'message' => e.message,
        'data' => e.data,
        'operation_input' => operation_input
      )
      [400, { 'content-type' => 'application/json' }, [e.as_json.to_json]]
    rescue => e
      log = {
        'message' => 'Exception raised',
        'exception_message' => e.message,
        'exception_klass' => e.class.to_s,
        'exception_backtrace' => e.backtrace
      }
      logger&.fatal(log)
      [500, { 'content-type' => 'application/json' }, [log.to_json]]
    end

    private

    def get_current_time
      Process.clock_gettime(Process::CLOCK_REALTIME, :second).to_i
    end

    def render_error(error, data = {}, code = 400)
      [
        code,
        { 'content-type' => 'application/json' },
        [JSON.dump({ 'error' => error, 'data' => data })]
      ]
    end

    def parse_request_body(request)
      Simdjson.parse(request.body.read)
    end
  end
end
