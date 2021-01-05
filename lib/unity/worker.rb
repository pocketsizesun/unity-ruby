# frozen_string_literal: true

module Unity
  class Worker
    include Shoryuken::Worker

    def self.inherited(base)
      super
      shoryuken_options({ auto_delete: true, body_parser: :json })
    end

    def self.queue=(arg)
      shoryuken_options(queue: arg.to_s)
    end

    def perform(_sqs_msg, data)
      call(data)
    end

    def call(data)
      raise "#call not implemented in #{self.class}"
    end
  end
end
