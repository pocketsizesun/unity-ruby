# frozen_string_literal: true

module Unity
  class Application
    attr_reader   :booted_at, :operations
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

    def initialize
      @module = find_module
      @logger = ::Logger.new(STDOUT)
      @operations = {}
      @booted_at = Process.clock_gettime(Process::CLOCK_REALTIME, :second).to_i
      @rack_app = nil
      @file_configurations = {}
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

      # build rack app
      @rack_app = build_rack_app
    end

    def find_operation(name)
      operations[name.to_s]
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
          run Unity::Middlewares::HealthCheckMiddleware.new(__self__)
        end

        use Unity::Middlewares::RequestParserMiddleware

        __self__.config.middlewares.each do |middleware|
          use middleware, app: __self__
        end

        run Unity::Middlewares::OperationExecutorMiddleware.new(__self__)
      end.to_app
    end
  end
end
