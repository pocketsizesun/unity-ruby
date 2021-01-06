# frozen_string_literal: true

require 'aws-sdk-dynamodbstreams'
require 'aws-sdk-dynamodbstreams-event-parser'

module Unity
  class DynamoDBStreamWorker
    include Shoryuken::Worker

    def self.inherited(base)
      super
      shoryuken_options(auto_delete: true)
    end

    def self.event_parser
      @event_parser ||= Aws::DynamoDBStreams::EventParser.new
    end

    def self.queue=(arg)
      shoryuken_options(queue: arg.to_s)
    end

    def perform(_sqs_msg, body)
      Unity.logger&.debug(
        'message' => "process dynamodb stream record '#{self.class}'",
        'body' => body
      )
      event = self.class.event_parser.parse(body)
      call(event)
    end

    def call(event)
      raise "#call not implemented in #{self.class}"
    end
  end
end
