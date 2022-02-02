# frozen_string_literal: true

module Unity
  class EventHandler
    def self.call(event)
      new.call(event)
    end

    def call(event)
    end

    def retry_execution!(options = {})
      raise RetryExecution, options
    end

    class RetryExecution < StandardError
      attr_reader :options

      DEFAULT_OPTIONS = { max_retries: nil, retry_in: 5 }.freeze

      def initialize(options)
        super()
        @options = options
      end

      def max_retries
        @options[:max_retries] || DEFAULT_OPTIONS[:max_retries]
      end

      def retry_in
        @options[:retry_in] || DEFAULT_OPTIONS[:retry_in]
      end
    end
  end
end
