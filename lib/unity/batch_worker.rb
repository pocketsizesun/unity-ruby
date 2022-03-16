# frozen_string_literal: true

module Unity
  class BatchWorker
    include Shoryuken::Worker

    def self.inherited(base)
      super
      shoryuken_options(auto_delete: true, batch: true)
    end

    def self.queue=(arg)
      shoryuken_options(queue: arg.to_s)
    end

    def self.enqueue(*args)
      Unity.logger&.debug "enqueue job '#{self.class}' with arguments '#{args.inspect}'"
      perform_async(JSON.dump(args))
    end

    def self.enqueue_in(delay, *args)
      Unity.logger&.debug "enqueue job '#{self.class}' with arguments '#{args.inspect}' (delay=#{delay})"
      perform_in(delay, JSON.dump(args))
    end

    def perform(_sqs_msg, items)
      Unity.logger&.debug "perform job '#{self.class}' with body '#{body}'"
      items = items.map { |item| JSON.parse(item) }
      call(items)
    end

    def call(items)
      raise "#call not implemented in #{self.class}"
    end
  end
end
