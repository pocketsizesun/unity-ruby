require 'logger'
require 'ostruct'
require 'json'
require 'time'
require 'singleton'
require 'dotenv/load'
require 'http'
require 'connection_pool'
require 'rack'
require 'rack/builder'
require 'unity/version'
require 'unity/error'
require 'unity/urn'
require 'unity/logger'
require 'unity/application'
require 'unity/authentication'
require 'unity/middleware_stack'
require 'unity/common_logger'
require 'unity/event'
require 'unity/event_emitter'
require 'unity/operation'
require 'unity/operation_context'
require 'unity/operation_policy'

# utils
require 'unity/utils/dynamo_service'
require 'unity/utils/redis_service'

module Unity
  def app_class=(klass)
    @app_class = klass
  end

  def app_class
    @app_class
  end

  def application
    @application ||= app_class.instance
  end

  def logger
    application.logger
  end

  def logger=(arg)
    application.logger = arg
  end

  module_function :app_class=, :app_class, :application, :logger, :logger=
end
