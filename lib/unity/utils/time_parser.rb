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
    end
  end
end
