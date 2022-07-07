# frozen_string_literal: true

module Unity
  class LocalCache
    Entry = Struct.new(:ttl, :value)

    def initialize
      @data = Hash.new
    end

    def clear
      @data.clear
    end

    def [](key)
      get(key)
    end

    def fetch(key, **kwargs, &block)
      entry = get_entry(key)
      return entry.value unless entry.nil?

      value = yield
      set(key, value, **kwargs)
      value
    end

    def get(key, default = nil)
      entry = get_entry(key)
      return default if entry.nil?

      entry.value
    end

    def set(key, value, ex: nil, exat: nil)
      ttl = \
        if !exat.nil?
          exat
        elsif !ex.nil?
          Unity.current_timestamp + ex
        end
      @data[key] = Entry.new(ttl, value)
      true
    end

    def delete(key)
      @data.delete(key)
    end

    private

    def get_entry(key)
      return if @data[key].nil?

      if !@data[key].ttl.nil? && @data[key].ttl <= Unity.current_timestamp
        @data.delete(key)
        return
      end

      @data[key]
    end
  end
end
