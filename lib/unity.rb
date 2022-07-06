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
require 'active_model'
require 'unity/version'
require 'unity/configuration'
require 'unity/error'
require 'unity/urn'
require 'unity/time_id'
require 'unity/time_uuid'
require 'unity/model'
require 'unity/application'
require 'unity/coordination'
require 'unity/event'
require 'unity/event_handler'
require 'unity/middleware'
require 'unity/middlewares/health_check_middleware'
require 'unity/middlewares/operation_executor_middleware'
require 'unity/middlewares/request_parser_middleware'
require 'unity/operation_input'
require 'unity/operation_output'
require 'unity/operation'
require 'unity/operation_context'
require 'unity/record_handler'

# utils
require 'unity/utils/dynamo_filter_expression_builder'
require 'unity/utils/dynamo_date_range_with_time_id_query'
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

  def self.coordination
    @coordination ||= Unity::Coordination.new
  end

  def self.report_exception(tag = '@', &_block)
    yield
  rescue Exception => e # rubocop:disable Lint/RescueException
    Unity.logger&.fatal(
      'message' => "[#{tag}] uncaught exception: #{e.message} (#{e.class})",
      'backtrace' => e.backtrace
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
end
