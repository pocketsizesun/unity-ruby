# frozen_string_literal: true

module Unity
  module EventConsumer
    class Container
      attr_reader :sqs, :sqs_queue_url, :concurrency, :workers_count, :health_check_pipes

      WorkerSpec = Struct.new(:pid, :input, :output)

      def initialize(options = {})
        @queue_name = options.fetch(:queue)
        @event_handlers = Unity.application.event_handlers
        @workers_count = options.fetch(:workers_count, 2)
        @concurrency = options.fetch(:concurrency, 2)
        @workers_queue = Queue.new
        @workers = {}
        @workers_pids = []
        @sqs = Aws::SQS::Client.new(options.fetch(:sqs_config, {}))
        @terminate = false

        Signal.trap('INT') { stop }
        Signal.trap('TERM') { stop }
      end

      def stop
        @terminate = true
      end

      def run
        @sqs_queue_url = @sqs.get_queue_url(queue_name: @queue_name)&.queue_url
        @health_check_pipes = IO.pipe

        @workers_count.times do |worker_index|
          worker_spec = spawn_worker
          @workers_queue << worker_spec
          @workers[worker_index] = worker_spec
        end

        check_workers_health

        Unity.logger&.info "[event:consumer] start container (pid=#{Process.pid})"
        loop do
          break if @terminate == true

          sqs_recv_result = @sqs.receive_message(
            queue_url: @sqs_queue_url,
            wait_time_seconds: 8
          )
          Unity.logger&.debug "SQS receive messages count: #{sqs_recv_result.messages.length}"
          sqs_recv_result.messages.each do |message|
            work_data = {
              'sqs_receipt_handle' => message.receipt_handle,
              'sqs_message_id' => message.message_id,
              'sqs_message_body' => message.body
            }
            worker = nil
            begin
              worker = @workers_queue.pop
              worker.input.puts '$w'
              worker.input.puts work_data.to_json
            ensure
              @workers_queue << worker unless worker.nil?
            end
          end

          check_workers_health
        end

        until @workers_queue.length == 0
          worker = @workers_queue.pop
          worker.input.puts '$e'
        end

        @workers.each_value do |w|
          Process.waitpid2(w.pid)
        end

        Unity.logger&.info "event:consumer terminated"
      rescue Aws::SQS::Errors::NonExistentQueue
        abort "SQS Queue '#{@queue_name}' does not exists"
      end

      private

      def check_workers_health
        @workers.each_value do |worker|
          Unity.logger&.debug "check worker '#{worker.pid}' health"
          worker.input.puts '$ping'
          pipe_readable = @health_check_pipes[0].wait_readable(2)
          read_data = pipe_readable&.gets&.strip
          if @terminate == false && (pipe_readable.nil? || read_data != '$pong')
            Unity.logger&.error "worker #{worker.pid} is dead, replacing it"
            replace_worker(worker)
          end
        end
      end

      def replace_worker(worker)
        Process.kill('KILL', worker.pid)
        Process.waitpid2(worker.pid)
        new_worker = spawn_worker
        worker.input = new_worker.input
        worker.output = new_worker.output
        worker.pid = new_worker.pid
      end

      def spawn_worker
        pipes = IO.pipe.tap { |arr| arr.each { |pipe| pipe.sync = true } }
        worker_pid = fork do
          Unity::EventConsumer::Worker.run(self, pipes)
        end
        WorkerSpec.new(worker_pid, pipes[1], pipes[0])
      end
    end
  end
end
