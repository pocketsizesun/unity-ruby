# frozen_string_literal: true

module Unity
  module Utils
    module Callable
      def call(*args)
        new.call(*args)
      end
    end
  end
end
