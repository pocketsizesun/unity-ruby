# frozen_string_literal: true

module Unity
  class Worker
    include Shoryuken::Worker

    def self.perform_in(delay, *args)
      super(delay, JSON.dump(args))
    end

    def self.perform_at(delay, *args)
      super(delay, JSON.dump(args))
    end

    def self.perform_async(*args)
      super(JSON.dump(args))
    end
  end
end
