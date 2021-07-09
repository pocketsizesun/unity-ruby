# frozen_string_literal: true

$LOAD_PATH << File.realpath(File.dirname(__FILE__) + '/../lib')
ENV['TZ'] = 'UTC'

require 'bundler/setup'
require 'unity'
require_relative 'application'

<%= @app_module_name %>::Application.load!
