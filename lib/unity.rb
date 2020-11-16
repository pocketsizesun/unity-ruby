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
  def self.app_class=(klass)
    @app_class = klass
  end

  def self.app_class
    @app_class
  end

  def self.application
    @application ||= app_class.instance
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
    @env ||= 'development'
  end

  def self.environment
    env
  end

  def self.environment=(arg)
    self.env = arg
  end
end
