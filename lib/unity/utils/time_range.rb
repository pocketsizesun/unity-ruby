# frozen_string_literal: true

module Unity
  module Utils
    class TimeRange
      def self.generate(from, to, interval)
        new(from, to, interval).to_h
      end

      def initialize(from, to, interval)
        @from = from
        @to = to
        @interval = interval
      end

      def to_h
        hash = {}
        curr_time = @from
        while curr_time <= @to
          hash[key_for(curr_time)] = []
          curr_time = next_time(curr_time)
        end
        hash
      end

      private

      def next_time(time)
        case @interval
        when 'hourly'
          time + 3600
        when 'daily'
          time + 86_400
        when 'weekly'
          time + 604_800
        when 'monthly'
          (time.to_date + 1).to_time
        end
      end

      def key_for(time)
        case @interval
        when 'hourly'
          time.strftime('%Y-%m-%d %H:00:00')
        when 'daily'
          time.strftime('%Y-%m-%d')
        when 'weekly'
          date = time.to_date
          begin
            Date.commercial(date.year, date.cweek, 1).strftime('%Y-%m-%d')
          rescue Date::Error => e
            raise e unless date.cweek == 53

            Date.commercial(date.year - 1, date.cweek, 1).strftime('%Y-%m-%d')
          end
        when 'monthly'
          time.strftime('%Y-%m-01')
        else
          nil
        end
      end
    end
  end
end
