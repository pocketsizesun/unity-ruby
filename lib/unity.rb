# frozen_string_literal: true

require 'socket'
require 'logger'
require 'securerandom'
require 'ostruct'
require 'json'
require 'time'
require 'singleton'
require 'erb'
require 'yaml'

# 3rd party libs
require 'dotenv/load'
require 'http'
require 'connection_pool'
require 'aws-sdk-sns'
require 'rack'
require 'rack/builder'
require 'shoryuken'
require 'active_model'
require 'zeitwerk'

# gem files
require 'unity/version'
require 'unity/configuration'
require 'unity/error'
require 'unity/errors/event_handler_not_found'
require 'unity/urn'
require 'unity/time_id'
require 'unity/time_uuid'
require 'unity/logger'
require 'unity/model'
require 'unity/model_attributes/tagset_model_attribute'
require 'unity/application'
require 'unity/coordination'
require 'unity/event'
require 'unity/event_emitter'
require 'unity/event_handler'
require 'unity/event_store'
require 'unity/event_worker'
require 'unity/middleware'
require 'unity/middlewares/health_check_middleware'
require 'unity/middlewares/operation_executor_middleware'
require 'unity/middlewares/request_parser_middleware'
require 'unity/operation'
require 'unity/operation_context'
require 'unity/record_handler'
require 'unity/batch_worker'
require 'unity/worker'

# utils
require 'unity/utils/callable'
require 'unity/utils/dynamo_service'
require 'unity/utils/dynamo_filter_expression_builder'
require 'unity/utils/dynamo_date_range_with_time_id_query'
require 'unity/utils/elastic_search_service'
require 'unity/utils/redis_service'
require 'unity/utils/s3_service'
require 'unity/utils/tagset'
require 'unity/utils/time_parser'

Encoding.default_internal = Encoding::UTF_8
Encoding.default_external = Encoding::UTF_8

module Unity
  extend self

  def applications
    @applications ||= []
  end

  def application
    @application
  end

  def application=(app)
    @application ||= app
  end

  def logger
    application.logger
  end

  def logger=(arg)
    application.logger = arg
  end

  def env=(arg)
    @env = arg.to_s
  end

  def env
    @env ||= ENV['APP_ENV'] || ENV.fetch('UNITY_ENV', 'development')
  end

  def environment
    env
  end

  def environment=(arg)
    self.env = arg
  end

  def root
    @root ||= Dir.pwd
  end

  def event_emitter
    return @event_emitter unless @event_emitter.nil?
    return nil unless Unity.application.config.event_emitter_enabled == true

    @event_emitter = Unity::EventEmitter.new(Unity.application.name)
  end

  def event_store
    @event_store ||= Unity::EventStore.new
  end

  def coordination
    @coordination ||= Unity::Coordination.new
  end

  def report_exception(name = nil, &_block)
    yield
  rescue Exception => e
    Unity.logger&.fatal(
      'error' => e.message,
      'report_exception_name' => name,
      'exception_klass' => e.class.to_s,
      'exception_backtrace' => e.backtrace
    )
    raise e
  end

  def gem_path
    @gem_path ||= File.realpath(File.dirname(__FILE__) + '/../')
  end

  def load_tasks
    Dir.glob("#{gem_path}/lib/tasks/{*,*/**}.rake").each do |filename|
      load filename
    end
    application&.load_tasks
  end

  def concurrency=(arg)
    application.config.concurrency = arg.to_i
  end

  def concurrency
    application.config.concurrency
  end

  def cache
    @cache ||= Unity::Utils::RedisService.instance
  end

  def dynamodb
    @dynamodb ||= Unity::Utils::DynamoService.instance
  end

  def s3
    @s3 ||= Unity::Utils::S3Service.instance
  end
end
