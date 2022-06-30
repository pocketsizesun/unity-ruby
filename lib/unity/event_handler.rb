# frozen_string_literal: true

module Unity
  class EventHandler
    def self.call(event)
      new.call(event)
    end

    def call(event)
    end
  end
end
