# frozen_string_literal: true

module Unity
  class Event
    attr_reader :id, :name, :date, :namespace, :type, :data

    def self.parse(str)
      data = JSON.parse(str)
      new(
        id: data['id'],
        date: Time.at(data['date'].to_f / 1000.0),
        name: data['name'],
        data: data['data']
      )
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
