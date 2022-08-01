# frozen_string_literal: true

module Unity
  class Event
    attr_reader :id, :type, :date, :data

    def self.from_json(item)
      new(
        id: item['id'],
        type: item['type'],
        date: item['date'],
        data: item['data']
      )
    end

    def initialize(type:, id: SecureRandom.uuid, date: Time.now, data: {})
      @id = id
      @type = type
      @date = date
      @data = data
    end

    def [](key)
      @data[key]
    end

    def source
      @type.slice(0, @type.index(':'))
    end

    def deduplication_id
      Digest::SHA256.hexdigest(
        Oj.dump([@type, @date.to_i, @data], mode: :compat)
      )
    end

    def content_sha256
      Digest::SHA256.hexdigest(Oj.dump(@data, mode: :compat))
    end

    def as_json(*)
      {
        'id' => @id,
        'type' => @type,
        'date' => @date.to_i,
        'data' => @data
      }
    end

    def to_json(*)
      as_json.to_json
    end
  end
end
