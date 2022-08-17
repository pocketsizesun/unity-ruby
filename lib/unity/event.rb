# frozen_string_literal: true

module Unity
  class Event
    attr_reader :id, :type, :date, :data, :replay_name

    def self.from_event_bridge(item)
      new(
        id: item['id'],
        type: item['detail-type'],
        date: Time.parse(item['time']),
        data: item['detail'],
        replay_name: item['replay-name']
      )
    end

    def self.from_json(item)
      new(
        id: item['id'],
        type: item['type'],
        date: item['date'],
        data: item['data'],
        replay_name: item['replay_name']
      )
    end

    def initialize(attributes = {})
      @id = attributes[:id] || SecureRandom.uuid
      @type = attributes[:type]
      @date = attributes[:date] || Time.now
      @data = attributes[:data].is_a?(Hash) ? attributes[:data] : {}
      @replay_name = attributes[:replay_name]
    end

    def [](key)
      @data[key]
    end

    def source
      @type.slice(0, @type.index(':'))
    end

    def deduplication_id
      sha256 = Digest::SHA256.new
      sha256 << @type
      sha256 << @date.to_i.to_s
      sha256 << @data.to_json
      sha256.hexdigest
    end

    def content_sha256
      Digest::SHA256.hexdigest(JSON.dump(@data))
    end

    def replayed?
      !@replay_name.nil?
    end

    def as_json(*)
      {
        'id' => @id,
        'type' => @type,
        'date' => @date.to_i,
        'data' => @data,
        'replay_name' => @replay_name
      }
    end

    def to_json(*)
      as_json.to_json
    end
  end
end
