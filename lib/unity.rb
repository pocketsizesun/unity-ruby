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
require 'connection_pool'
require 'rack'
require 'rack/builder'
require 'active_model'
require 'zeitwerk'
require 'unity-logger'

require 'unity/version'
require 'unity/configuration'
require 'unity/error'
require 'unity/time_id'
require 'unity/model'
require 'unity/application'
require 'unity/event'
require 'unity/event_handler'
require 'unity/route'
require 'unity/route_controller'
require 'unity/middleware'
require 'unity/middlewares/operation_executor_middleware'
require 'unity/middlewares/router_middleware'
require 'unity/operation_input'
require 'unity/operation_output'
require 'unity/operation_context'
require 'unity/operation'
require 'unity/dependency_container'

# model
require_relative 'unity/tag_set'

# utils
require 'unity/utils/time_parser'

Encoding.default_internal = Encoding::UTF_8
Encoding.default_external = Encoding::UTF_8

module Unity
  @dependency_container = ::Unity::DependencyContainer.new

  module_function

  # @sg-ignore
  # @return [Unity::Application]
  def application
    @application
  end

  # @sg-ignore
  # @param inst [Unity::Application]
  # @return [void]
  def application=(inst)
    @application = inst
  end

  # @return [Logger]
  def logger
    application.logger
  end

  # @param arg [Logger, nil]
  # @return [void]
  def logger=(arg)
    application.logger = arg
  end

  # @param arg [String]
  # @return [void]
  def env=(arg)
    @env = arg.to_s
  end

  # @sg-ignore
  # @return [String]
  def env
    @env ||= ENV['APP_ENV'] || ENV.fetch('UNITY_ENV', 'development')
  end

  # @return [String]
  def environment
    env
  end

  # @param arg [String]
  # @return [void]
  def environment=(arg)
    self.env = arg
  end

  # @sg-ignore
  # @return [String]
  def root
    @root ||= Dir.pwd
  end

  # @param tag [String]
  # @return [void]
  def report_exception(tag = '@', &_block)
    yield
  rescue Exception => e # rubocop:disable Lint/RescueException
    Unity.logger&.fatal(
      'message' => "[#{tag}] uncaught exception: #{e.message} (#{e.class})",
      'backtrace' => e.backtrace
    )

    raise e
  end

  # @sg-ignore
  # @return [String]
  def gem_path
    @gem_path ||= File.realpath(File.dirname(__FILE__) + '/../')
  end

  # @return [void]
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

  # @sg-ignore
  # @return [Integer]
  def concurrency
    @concurrency ||= ENV.fetch('CONCURRENCY', 4).to_i
  end

  # @sg-ignore
  # @param value [Integer]
  # @return [void]
  def concurrency=(value)
    @concurrency = value.to_i
  end

  # @param timeout [Integer]
  # @return [ConnectionPool]
  def build_connection_pool(timeout: 5, &block)
    ConnectionPool.new(size: concurrency, timeout: timeout, &block)
  end

  # @return [Unity::DependencyContainer]
  def di(name = nil)
    if !name.nil?
      @dependency_container.use(name)
    else
      @dependency_container
    end
  end
end
