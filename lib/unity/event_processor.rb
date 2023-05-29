# frozen_string_literal: true

module Unity
  class EventProcessor
    def initialize(&block)
      @handlers = {}
      instance_exec(&block) unless block.nil?
    end

    def on(type, klass = nil, &block)
      @handlers[type] ||= []
      @handlers[type] << klass || block
    end

    def call(event)
      return false if @handlers[event.type].nil?

      @handlers[event.type].each do |handler|
        handler.call(event)
      end

      true
    end
  end
end
