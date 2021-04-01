# frozen_string_literal: true

module Unity
  module Utils
    class Tagset
      include Enumerable

      def self.sanitize(tags)
        new(tags).to_h
      end

      def initialize(tags)
        @tags = tags.transform_keys(&:to_s).transform_values! do |v|
          v = v.to_s.strip
          !v.empty? ? v : nil
        end
        @tags.compact!
      end

      def each(&block)
        @tags.each(&block)
      end

      def [](key)
        @tags[key]
      end

      def []=(key, value)
        value = value.to_s.strip
        return if v.empty?

        @tags[key.to_s] = value
      end

      def delete(key)
        @tags.delete(key)
      end

      def empty?
        @tags.empty?
      end

      def keys
        @tags.keys
      end

      def values
        @tags.values
      end

      def as_json
        @tags.as_json
      end

      def to_json(*args)
        @tags.to_json(*args)
      end

      def to_h
        @tags.dup
      end
    end
  end
end
