# frozen_string_literal: true

module Unity
  module Utils
    class TimeParser
      def self.parse(arg)
        case arg
        when Time then arg
        when String then Time.parse(arg)
        when Numeric then Time.at(arg)
        end
      end

      def self.round(time, interval)
        if interval.is_a?(Numeric)
          ts = time.to_i
          Time.at(ts - (ts % interval.to_i))
        else
          case interval.to_s
          when 'hourly'
            round(time, 3600)
          when 'daily'
            round(time, 86_400)
          when 'weekly'
            date = time.to_date
            begin
              Date.commercial(date.year, date.cweek, 1).to_time
            rescue Date::Error => e
              raise e unless date.cweek == 53

              Date.commercial(date.year - 1, date.cweek, 1).to_time
            end
          when 'monthly'
            Time.parse(time.strftime('%Y-%m-01'))
          else
            raise ArgumentError, "Unknown interval '#{interval}'"
          end
        end
      end
    end
  end
end
