# frozen_string_literal: true

module Unity
  class EventWorker
    include Shoryuken::Worker

    shoryuken_options auto_delete: true

    def self.queue=(arg)
      shoryuken_options(queue: arg.to_s)
    end

    def perform(sqs_msg, body)
      Unity.logger&.debug "process event: #{body}"
      event = Unity::Event.parse(body)
      event_handler = Unity.application.find_event_handler(event.name)
      if event_handler.nil?
        Unity.logger&.error(
          'message' => "unable to find event handler for '#{event.name}'",
          'event' => event
        )
        return
      end
      event_handler.call(event)
      true
    rescue Unity::EventHandler::RetryExecution => e
      if e.max_retries.nil? || sqs_msg.attributes['ApproximateReceiveCount'] < e.max_retries
        Unity.logger&.warn(
          'message' => "retry event execution: #{event.id}",
          'event' => event,
          'reason' => e.reason
        )
        raise e
      else
        Unity.logger&.warn(
          'message' => "event '#{event.id}' execution has failed and will not be retried",
          'event' => event,
          'reason' => e.reason,
          'retries' => sqs_msg.attributes['ApproximateReceiveCount'],
          'max_retries' => e.max_retries
        )
      end
    rescue Exception => e
      Unity.logger&.fatal(
        'error' => e.message,
        'exception_klass' => e.class.to_s,
        'exception_backtrace' => e.backtrace,
        'event_body' => body
      )
      raise e
    end
  end
end
