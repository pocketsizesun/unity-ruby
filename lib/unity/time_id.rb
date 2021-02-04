# frozen_string_literal: true

module Unity
  # Date-relative UUID generation.
  class TimeId
    NUM_RANDOM_BITS = 23

    # Generates a time-sortable, 64-bit UUID.
    #
    # @example
    #   Druuid.gen
    #   # => 11142943683383068069
    # @param [Time] time of UUID
    # @param [Numeric] epoch offset
    # @return [Bignum] UUID
    def self.random
      from(Time.now)
    end

    def self.from(time)
      ((time.to_f * 1e3).round << NUM_RANDOM_BITS) | (SecureRandom.random_number * 1e16).round % (2 ** NUM_RANDOM_BITS)
    end

    # Determines when a given UUID was generated.
    #
    # @param [Numeric] uuid
    # @param [Numeric] epoch offset
    # @return [Time] when UUID was generated
    # @example
    #   Druuid.time 11142943683383068069
    #   # => 2012-02-04 00:00:00 -0800
    def self.time(id)
      Time.at((id >> NUM_RANDOM_BITS) / 1e3)
    end

    def self.date_as_string(id)
      time(id).strftime('%Y-%m-%d')
    end

    # Determines the minimum UUID that could be generated for the given time.
    #
    # @param [Time] time of UUID
    # @param [Numeric] epoch offset
    # @return [Bignum] UUID
    # @example
    #   Druuid.min_for_time
    #   # => 11142943683379200000
    def self.min_for_time(time = Time.now)
      (time.round.to_i * 1e3).to_i << NUM_RANDOM_BITS
    end

    def self.min(time = Time.now)
      from(time) >> NUM_RANDOM_BITS << NUM_RANDOM_BITS
    end

    # Determines the maximum UUID that could be generated for the given time.
    #
    # @param [Time] time of UUID
    # @param [Numeric] epoch offset
    # @return [Bignum] UUID
    def self.max_for_time(time = Time.now)
      from(time) | 0b111_1111_1111_1111_1111_1111
    end

    def self.range(from, to)
      min_for_time(from)..max_for_time(to)
    end
  end
end
