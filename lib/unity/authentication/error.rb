# frozen_string_literal: true

module Unity
  module Authentication
    # Authentication helper class (IAM)
    class Error < StandardError
      attr_reader :code, :data

      def initialize(code, data)
        super(
          case code
          when 401 then 'Authentication error'
          when 403 then 'Forbidden'
          else "Auth error: #{code}"
          end
        )
        @code = code
        @data = data
      end

      def as_json
        { 'error' => message, 'data' => nil }
      end
    end
  end
end
