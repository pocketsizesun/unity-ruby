# frozen_string_literal: true

module Unity
  class Event
    attr_reader :id, :name, :date, :namespace, :type, :data

    EventMalformatedError = Class.new(StandardError)

    def self.parse(str)
      data = JSON.parse(str)
      new(
        id: data.fetch('id'),
        date: Time.at(data.fetch('date').to_f / 1000.0),
        name: data.fetch('name'),
        data: data.fetch('data')
      )
    rescue KeyError, JSON::ParserError
      raise EventMalformatedError
    end

    def initialize(attributes = {})
      @id = attributes.fetch(:id) { SecureRandom.uuid }
      @date = attributes.fetch(:date) { Time.now }
      @name = attributes.fetch(:name)
      @data = attributes.fetch(:data) { Hash.new }
      @namespace, @type = @name.split(':')
    end

    def as_data
      {
        'id' => id,
        'name' => "#{namespace}:#{type}",
        'date' => (date.to_f * 1000.0).to_i,
        'data' => data
      }
    end

    def to_json
      as_data.to_json
    end

    def to_h
      { id: id, name: name, date: date, data: data }
    end
  end
end
