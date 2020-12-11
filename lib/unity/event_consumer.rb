require 'aws-sdk-sqs'
require 'unity/event_consumer/container'
require 'unity/event_consumer/worker'

module Unity
  module EventConsumer
    def self.run(options)
      container = Unity::EventConsumer::Container.new(options)
      container.run
    end
  end
end
