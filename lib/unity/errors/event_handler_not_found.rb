# frozen_string_literal: true

module Unity
  module Errors
    class EventHandlerNotFound < Unity::Error
      attr_reader :name

      def initialize(name)
        @name = name
        super("event handler '#{name}' not found")
      end
    end
  end
end
