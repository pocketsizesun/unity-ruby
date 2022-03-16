# frozen_string_literal: true

module Unity
  class Application
    attr_reader   :name, :config, :initialized_at, :operations, :policies, :event_handlers
    attr_accessor :logger

    @operations = {}

    def self.instance
      return @instance unless @instance.nil?

      @instance = new.tap do |app|
        Unity.application = app
      end
    end

    def self.configure(&block)
      instance.configure(&block)
    end

    def self.operation(name, klass = nil, &block)
      instance.operation(name, klass, &block)
    end

    def self.event_handler(name, klass = nil, &block)
      instance.event_handler(name, klass, &block)
    end

    def self.setup(&block)
      instance.setup(&block)
    end

    def initialize
      @name = nil
      @config = Unity::Configuration.new
      @logger = nil
      @event_handlers = Concurrent::Hash.new
      @operations = Concurrent::Hash.new
      @initialized_at = Time.now.to_i
      @file_configurations = {}
      @loaded = false
      @environment_config_loaded = false
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
      block.call(config, self)

      # load specific environment config
      if @environment_config_loaded == false
        @environment_config_loaded = true
        env_config_file = Unity.root + "/config/environments/#{Unity.env}.rb"
        if File.exist?(env_config_file)
          load env_config_file
        end
      end
    end

    def setup(&block)
      load!
      instance_exec(&block)
    end

    def operation(name, klass = nil, &block)
      @operations[name.to_s] = klass || block
    end

    def event_handler(name, klass = nil, &block)
      @event_handlers[name.to_s] ||= []
      @event_handlers[name.to_s] << klass || block
    end

    def find_operation(name)
      @operations[name.to_s]
    end

    def find_event_handlers(name)
      return [] unless @event_handlers.key?(name)

      @event_handlers[name]
    end

    # @param [Rack::Request] request
    # @return [Hash]
    def request_body_parser(request)
      Oj.load(request.body) || {}
    end

    def to_rack_app
      self_ref = self

      Rack::Builder.new do
        map '/_status' do
          run Unity::Middlewares::HealthCheckMiddleware.new
        end

        use Unity::Middlewares::RequestParserMiddleware, unity_app: self_ref

        self_ref.config.middlewares.each do |middleware|
          use middleware, app: self_ref
        end

        run Unity::Middlewares::OperationExecutorMiddleware.new(self_ref)
      end.to_app
    end

    private

    def render_error(error, data = {}, code = 400)
      [
        code,
        { 'content-type' => 'application/json' },
        [JSON.dump({ 'error' => error, 'data' => data })]
      ]
    end

    def load!
      return if @loaded == true

      @loaded = true

      @zeitwerk = Zeitwerk::Loader.new
      @zeitwerk.push_dir('lib')
      # load additionnal paths
      config.autoload_paths.each do |path|
        @zeitwerk.push_dir(path)
      end
      @zeitwerk.setup
      @zeitwerk.eager_load

      # init time zone
      ENV['TZ'] = config.time_zone

      @logger = config.logger || Unity::Logger.new(STDOUT)
      @logger&.level = config.log_level

      # event worker
      unless config.event_worker_queue.nil?
        Unity::EventWorker.queue = config.event_worker_queue
      end

      # run initializers
      Dir.glob("#{Unity.root}/config/initializers/*.rb").each do |item|
        file = File.basename(item)
        @logger&.debug "load initializer file: #{file}"
        require "#{Unity.root}/config/initializers/#{file}"
      end

      # Configure Shoryuken defaults
      # - change Shoryuken logger
      # - cache visibility timeout by default
      if defined?(Shoryuken)
        Shoryuken::Logging.logger = logger || Logger.new('/dev/null')
        Shoryuken.cache_visibility_timeout = true
      end
    end
  end
end
