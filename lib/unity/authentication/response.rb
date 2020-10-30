# frozen_string_literal: true

module Unity
  module Authentication
    class Response
      attr_reader :user, :account_urn, :account_id, :policy_urn,
                  :matched_statement, :tags, :raw_data, :user_urn

      def initialize(attributes)
        @user_urn = Unity::URN.new(attributes.fetch('user_urn'))
        @policy_urn = \
          if attributes.key?('policy_urn')
            Unity::URN.new(attributes.fetch('policy_urn'))
          end
        @policy_statement_urn = \
          if attributes.key?('policy_statement_urn')
            Unity::URN.new(attributes.fetch('policy_statement_urn'))
          end
      end

      def user_name
        @user_name ||= @user_urn.nss.split('/').last
      end
    end
  end
end
