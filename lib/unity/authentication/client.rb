# frozen_string_literal: true

module Unity
  module Authentication
    # Authentication helper class (IAM)
    class Client
      attr_reader :endpoint

      AUTHENTICATE_PARAMETERS = { 'Action' => 'AuthorizeToken' }.freeze
      DEFAULT_ENDPOINT_URL = 'https://api.iam.tikt.net'

      def initialize(endpoint = nil)
        @endpoint = \
          endpoint || ENV.fetch('TIKT_IAM_ENDPOINT', DEFAULT_ENDPOINT_URL)
        @http = HTTP.persistent(@endpoint)
      end

      def authenticate(token, action_name, options = {})
        req_data = {
          token: token,
          action_name: action_name,
          resource: options.fetch(:resource, nil),
          conditions: options.fetch(:conditions, nil),
          variables: options.fetch(:variables, nil)
        }
        r = @http.post('/', json: req_data, params: AUTHENTICATE_PARAMETERS)
        unless r.code == 200
          raise Unity::Authentication::Error.new(r.code, r.body.to_s)
        end

        Unity::Authentication::Response.new(r.parse(:json))
      end
    end
  end
end
