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
require 'rack'
require 'rack/builder'
require 'active_model'
require 'unity/version'
require 'unity/configuration'
require 'unity/error'
require 'unity/time_id'
require 'unity/time_uuid'
require 'unity/model'
require 'unity/application'
require 'unity/coordination'
require 'unity/event'
require 'unity/event_handler'
require 'unity/route'
require 'unity/route_controller'
require 'unity/middleware'
require 'unity/middlewares/operation_executor_middleware'
require 'unity/middlewares/router_middleware'
require 'unity/operation_input'
require 'unity/operation_output'
require 'unity/operation'
require 'unity/operation_context'
require 'unity/record_handler'

# model
require_relative 'unity/tag_set'
require_relative 'unity/model/tag_set_type'
ActiveModel::Type.register(:tagset, Unity::Model::TagSetType)

# utils
require 'unity/utils/time_parser'

Encoding.default_internal = Encoding::UTF_8
Encoding.default_external = Encoding::UTF_8

module Unity
  module_function

  # @param app_class [Class<Unity::Application>]
  def app_class=(klass)
    @app_class = klass
  end

  # @return [Class<Unity::Application>]
  def app_class
    @app_class
  end

  # @return [Unity::Application]
  def application
    @application
  end

  # @return [Unity::Application]
  def application=(inst)
    @application = inst
  end

  # @return [Logger]
  def logger
    application.logger
  end

  def logger=(arg)
    application.logger = arg
  end

  def env=(arg)
    @env = arg.to_s
  end

  # @return [String]
  def env
    @env ||= ENV['APP_ENV'] || ENV.fetch('UNITY_ENV', 'development')
  end

  # @return [String]
  def environment
    env
  end

  def environment=(arg)
    self.env = arg
  end

  # @return [String]
  def root
    @root ||= Dir.pwd
  end

  def coordination
    @coordination ||= Unity::Coordination.new
  end

  def report_exception(tag = '@', &_block)
    yield
  rescue Exception => e # rubocop:disable Lint/RescueException
    Unity.logger&.fatal(
      'message' => "[#{tag}] uncaught exception: #{e.message} (#{e.class})",
      'backtrace' => e.backtrace
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

  # @return [Integer]
  def current_timestamp
    Process.clock_gettime(Process::CLOCK_REALTIME, :second).to_i
  end

  # @return [Time]
  def current_time
    Time.at(Process.clock_gettime(Process::CLOCK_REALTIME, :second).to_i)
  end

  # @return [Integer]
  def concurrency
    @concurrency ||= ENV.fetch('CONCURRENCY', 4).to_i
  end

  # @param value [Integer]
  def concurrency=(value)
    @concurrency = value.to_i
  end
end
