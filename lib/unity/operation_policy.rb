# frozen_string_literal: true

module Unity
  class OperationPolicy
    attr_reader :context

    def initialize(context = nil)
      @context = context.is_a?(Hash) ? context : Unity::OperationContext.new
    end

    def call(args)
      raise "#call not implemented in #{self.class}"
    end
  end
end
