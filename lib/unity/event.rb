# frozen_string_literal: true

module Unity
  class Event
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

    def initialize(attributes)
      @id = attributes[:id] || SecureRandom.uuid
      @name = attributes.fetch(:name)
      @timestamp = attributes[:timestamp] || Time.now
      @data = attributes[:data] || {}
    end

    def [](key)
      data[key]
    end

    def deduplication_id
      Digest::SHA256.hexdigest(
        Oj.dump([name, timestamp.to_i, data], mode: :compat)
      )
    end

    def content_sha256
      Digest::SHA256.hexdigest(Oj.dump(data, mode: :compat))
    end

    def as_json(*)
      {
        'id' => id,
        'name' => name,
        'timestamp' => timestamp.to_i,
        'data' => data
      }
    end

    def to_json(*)
      as_json.to_json
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
