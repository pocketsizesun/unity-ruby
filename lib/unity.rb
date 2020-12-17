require 'socket'
require 'logger'
require 'securerandom'
require 'ostruct'
require 'json'
require 'symbol-fstring'
require 'time'
require 'singleton'
require 'dotenv/load'
require 'http'
require 'connection_pool'
require 'aws-sdk-sns'
require 'rack'
require 'rack/builder'
require 'unity/version'
require 'unity/error'
require 'unity/errors/event_handler_not_found'
require 'unity/urn'
require 'unity/time_id'
require 'unity/logger'
require 'unity/application'
require 'unity/authentication'
require 'unity/common_logger'
require 'unity/event'
require 'unity/event_emitter'
require 'unity/event_handler'
require 'unity/operation'
require 'unity/operation_context'
require 'unity/operation_policy'
require 'unity/middlewares/authentication_middleware'
require 'unity/middlewares/health_check_middleware'
require 'unity/middlewares/operation_executor_middleware'
require 'unity/middlewares/request_parser_middleware'

# utils
require 'unity/utils/dynamo_service'
require 'unity/utils/dynamo_filter_expression_builder'
require 'unity/utils/dynamo_date_range_with_time_id_query'
require 'unity/utils/redis_service'
require 'unity/utils/s3_service'

Encoding.default_internal = Encoding::UTF_8
Encoding.default_external = Encoding::UTF_8

module Unity
  def self.app_class=(klass)
    @app_class = klass
  end

  def self.app_class
    @app_class
  end

  def self.application
    @application ||= app_class&.instance
  end

  def self.logger
    application.logger
  end

  def self.logger=(arg)
    application.logger = arg
  end

  def self.env=(arg)
    @env = arg.to_s
  end

  def self.env
    @env ||= ENV.fetch('UNITY_ENV', 'development')
  end

  def self.environment
    env
  end

  def self.environment=(arg)
    self.env = arg
  end

  def self.root
    @root ||= Dir.pwd
  end

  def self.event_emitter
    return @event_emitter unless @event_emitter.nil?
    return nil unless Unity.application.config.event_emitter_enabled == true

    @event_emitter = Unity::EventEmitter.new(Unity.application.name)
  end
end
