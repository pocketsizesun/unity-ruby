# frozen_string_literal: true

module Unity
  class Event < Unity::Model
    attribute :id, :string
    attribute :name, :string
    attribute :timestamp, :datetime, default: -> { Time.now }
    attribute :data, default: -> { Hash.new }

    EventMalformatedError = Class.new(StandardError)

    def self.parse(str)
      data = JSON.parse(str)
      new(
        timestamp: Time.at(data.fetch('timestamp', data['date']).to_i),
        name: data.fetch('name'),
        data: data.fetch('data')
      )
    rescue KeyError, JSON::ParserError
      raise EventMalformatedError
    end

    def self.from_dynamo_item(item)
      new(
        id: item['id'],
        name: item['n'],
        timestamp: Time.at(item['t'].to_i),
        data: item['d']
      )
    end

    def id
      @id ||= Base64.urlsafe_encode64(
        Digest::SHA256.digest([timestamp, name, data].to_json)
      ).slice(0, 43)
    end

    def id=(arg)
      @id = arg
    end

    def deduplication_id
      Base64.urlsafe_encode64(
        Digest::SHA256.digest([name, data].to_json)
      ).slice(0, 43)
    end

    def content_sha256
      Digest::SHA256.hexdigest(data.to_json)
    end

    def as_sns_notification
      {
        'id' => id,
        'name' => name,
        'date' => timestamp.to_i * 1000,
        'timestamp' => timestamp.to_i,
        'data' => data
      }
    end

    def as_dynamo_item
      {
        'date' => timestamp.strftime('%Y-%m-%d'),
        'n' => name,
        'id' => id,
        't' => timestamp.to_i,
        'd' => data
      }
    end
  end
end
