# frozen_string_literal: true

module Unity
  class EventHandler
    # @param event [Unity::Event]
    # @return [Object]
    def self.call(event)
      new.call(event)
    end

    # @param event [Unity::Event]
    # @return [Object]
    def call(event)
      raise "#call not implemented in #{self.class.name}"
    end
  end
end
