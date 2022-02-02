# frozen_string_literal: true

module Unity
  class EventWorker
    include Shoryuken::Worker

    shoryuken_options auto_delete: false

    def self.queue=(arg)
      shoryuken_options(queue: arg.to_s)
    end

    def self.debug_mode
      @debug_mode
    end

    def self.debug_mode=(arg)
      @debug_mode = arg
    end

    def perform(sqs_msg, body)
      Unity.logger&.debug("incoming event: #{body}") if self.class.debug_mode == true

      # parse incoming event
      event = Unity::Event.parse(body)

      # retrieve all event handlers
      event_handlers = Unity.application.find_event_handlers(event.name)

      # check if there is no event handlers associated to that event
      if event_handlers.nil?
        Unity.logger&.warn(
          'message' => "there is no event handlers for '#{event.name}'",
          'event' => event
        )
        return
      end

      # execute event handlers
      event_handlers.each do |event_handler|
        event_handler.call(event)
      end

      # delete SQS message
      sqs_msg.delete

      true
    rescue Unity::EventHandler::RetryExecution => e
      if e.max_retries.nil? || sqs_msg.attributes['ApproximateReceiveCount'] < e.max_retries
        Unity.logger&.warn(
          'message' => "retry event execution: #{event.id}",
          'event' => event,
          'reason' => e.reason
        )
        sqs_msg.visibility_timeout = e.retry_in&.to_i || 1
        raise e
      else
        Unity.logger&.warn(
          'message' => "event '#{event.id}' execution has failed and will not be retried",
          'event' => event,
          'reason' => e.reason,
          'retries' => sqs_msg.attributes['ApproximateReceiveCount'],
          'max_retries' => e.max_retries
        )
        sqs_msg.delete
      end
    rescue Exception => e
      Unity.logger&.fatal(
        'error' => e.message,
        'exception_klass' => e.class.to_s,
        'exception_backtrace' => e.backtrace,
        'event_body' => body
      )
      sqs_msg.visibility_timeout = 5
      raise e
    end
  end
end
