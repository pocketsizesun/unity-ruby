# frozen_string_literal: true

module Unity
  class Event
    attr_reader :uuid, :date, :type, :data

    def self.parse(str)
      data = JSON.parse(str)
      new(
        uuid: data['uuid'],
        date: Time.at(data['date'].to_f / 1000.0),
        type: data['type'],
        data: data['data']
      )
    end

    def initialize(attributes = {})
      @uuid = attributes.fetch(:uuid) { SecureRandom.uuid }
      @date = attributes.fetch(:date) { Time.now.round }
      @type = attributes.fetch(:type).to_s
      @data = attributes.fetch(:data) { Hash.new }
    end

    def emitter
      @type.to_s.split(':').first
    end

    def as_data
      {
        'uuid' => @uuid,
        'date' => (@date.to_f * 1000.0).to_i,
        'type' => @type.to_s,
        'data' => @data
      }
    end

    def to_json
      as_data.to_json
    end

    def to_h
      { uuid: @uuid, date: @date.to_i, type: @type, data: @data }
    end

    def parse_date(value)
      return Time.now if value.nil?
      return Time.at(value.to_f / 1000.0) if value.is_a?(Integer)
      return value if value.is_a?(Time)
      Time.parse(value.to_s)
    end
  end
end
