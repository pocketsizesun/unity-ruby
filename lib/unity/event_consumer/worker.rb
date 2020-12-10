# frozen_string_literal: true

module Unity
  module EventConsumer
    class Worker
      def self.run(container, pipes)
        new(container, pipes).run
      end

      def initialize(container, pipes)
        @container = container
        @input, @output = pipes
        @thread_pool = Concurrent::FixedThreadPool.new(container.concurrency)
        @terminate = false

        Signal.trap('INT') { stop }
        Signal.trap('TERM') { stop }
      end

      def stop
        @terminate = true
      end

      def run
        Unity.logger&.info "[event:consumer] start worker (pid=#{Process.pid})"
        loop do
          Unity.logger&.debug 'waiting for work data'
          input_readable = @input.wait_readable(2)
          unless input_readable.nil?
            input = @input.gets.strip
            case input
            when '$w'
              work_data = JSON.parse(@input.gets.strip)
              process_work_data(work_data)
            when '$ping' then ping_request
            when '$e' then break
            end
          end

          break if @terminate == true
        end

        @thread_pool.shutdown

        sleep 0.5 until @thread_pool.shutdown?

        Unity.logger&.info "[event:consumer] worker '#{Process.pid}' exits"
      end

      private

      def delete_sqs_message(receipt_handle)
        @container.sqs.delete_message(
          queue_url: @container.sqs_queue_url,
          receipt_handle: receipt_handle
        )
      end

      def parse_event(str)
        Unity::Event.parse(str)
      end

      def process_work_data(work_data)
        event = parse_event(work_data['sqs_message_body'])
        event_handler = Unity.application.find_event_handler(event.name)
        if event_handler.nil?
          Unity.logger&.error(
            'message' => "unable to find event handler for '#{event.name}'",
            'work_data' => work_data
          )
          return
        end

        @thread_pool.post(work_data, event_handler) do |w_data, handler|
          handler.call(event)
          delete_sqs_message(w_data['sqs_receipt_handle'])
        end
      rescue Unity::Event::EventMalformatedError
        delete_sqs_message(work_data['sqs_receipt_handle'])
        Unity.logger&.fatal(
          'message' => 'unable to parse event from received work data',
          'work_data' => work_data
        )
      rescue => e
        Unity.logger&.fatal(
          'message' => "[event:consumer] exception: #{e.class}",
          'exception_message' => e.message,
          'exception_backtrace' => e.backtrace,
          'work_data' => work_data
        )
      end

      def ping_request
        @container.health_check_pipes[1].puts '$pong'
      end
    end
  end
end
