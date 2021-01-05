# frozen_string_literal: true

module Unity
  class Worker
    include Shoryuken::Worker

    def self.inherited(base)
      super
      shoryuken_options(auto_delete: true)
    end

    def self.queue=(arg)
      shoryuken_options(queue: arg.to_s)
    end

    def perform(_sqs_msg, body)
      args = JSON.parse(body)
      call(*args)
    end

    def call(*args)
      raise "#call not implemented in #{self.class}"
    end
  end
end
