# frozen_string_literal: true

module Unity
  # Date-relative UUID generation.
  class TimeId
    NUM_RANDOM_BITS = 23
    MAX_TIME_USEC = Rational(999999, 1)

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
      ms = (time.to_f * 1e3).round
      rand = (SecureRandom.random_number * 1e16).round
      id = ms << NUM_RANDOM_BITS
      id | rand % (2 ** NUM_RANDOM_BITS)
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
      ms = id >> NUM_RANDOM_BITS
      Time.at(ms / 1e3)
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
      ms = (time.to_f * 1e3).round
      ms << NUM_RANDOM_BITS
    end

    # Determines the maximum UUID that could be generated for the given time.
    #
    # @param [Time] time of UUID
    # @param [Numeric] epoch offset
    # @return [Bignum] UUID
    def self.max_for_time(time = Time.now)
      min_for_time(time) | 0b111_1111_1111_1111_1111_1111
    end
  end
end
