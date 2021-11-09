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
require 'unity/authentication'
require 'unity/coordination'
require 'unity/event'
require 'unity/event_emitter'
require 'unity/event_handler'
require 'unity/event_store'
require 'unity/event_worker'
require 'unity/middleware'
require 'unity/middlewares/authentication_middleware'
require 'unity/middlewares/health_check_middleware'
require 'unity/middlewares/operation_executor_middleware'
require 'unity/middlewares/request_parser_middleware'
require 'unity/operation'
require 'unity/operation_context'
require 'unity/operation_policy'
require 'unity/record_handler'
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
    @env ||= ENV['APP_ENV'] || ENV.fetch('UNITY_ENV', 'development')
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

  def self.event_store
    @event_store ||= Unity::EventStore.new
  end

  def self.coordination
    @coordination ||= Unity::Coordination.new
  end

  def self.report_exception(name = nil, &_block)
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

  def self.gem_path
    @gem_path ||= File.realpath(File.dirname(__FILE__) + '/../')
  end

  def self.load_tasks
    Dir.glob("#{gem_path}/lib/tasks/{*,*/**}.rake").each do |filename|
      load filename
    end
    application&.load_tasks
  end

  def self.concurrency=(arg)
    application.config.concurrency = arg.to_i
  end

  def self.concurrency
    application.config.concurrency
  end
end
