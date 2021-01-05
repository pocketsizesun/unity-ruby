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
  end
end
