# frozen_string_literal: true

module Unity
  module Application
    class EventHandler
      def self.call(event)
        new.call(event)
      end
    end
  end
end
