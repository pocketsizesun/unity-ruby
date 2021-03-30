# frozen_string_literal: true

module Unity
  class EventHandler
    RetryExecution = Class.new(StandardError) do
      attr_reader :options

      def initialize(options)
        super()
        @options = options
      end

      def max_retries
        @options.fetch(:max_retries, nil)
      end
    end

    def self.call(event)
      new.call(event)
    end

    def call(event)
    end

    def retry_execution!(options = {})
      raise RetryExecution, options
    end
  end
end
