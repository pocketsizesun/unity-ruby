# frozen_string_literal: true

module Unity
  module Utils
    class ElasticSearchService
      include Singleton

      def checkout(&block)
        @connection_pool.with(&block)
      end

      def cluster_health
        checkout { |conn| conn.cluster.health }
      end

      def search(*args)
        checkout do |conn|
          conn.search(*args)
        end
      end

      protected

      def initialize
        @connection_pool = ConnectionPool.new(
          pool_size: Unity.application&.config&.max_threads&.to_i || 4
        ) do
          Elasticsearch::Client.new(
            Unity.application&.config&.elasticsearch_options || {}
          )
        end
      end
    end
  end
end
