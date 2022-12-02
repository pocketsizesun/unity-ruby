# frozen_string_literal: true

module Unity
  module CLI
    class Command
      # @param args [Array<String>]
      def self.call(*args)
        new.call(*args)
      end

      def initialize
        @logger = Logger.new($stdout)
      end

      # @abstract
      # @param args [Array<String>]
      # @return [void]
      def call(*args); end
    end
  end
end
