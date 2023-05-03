# frozen_string_literal: true

module Unity
  class DependencyContainer
    include Enumerable

    def initialize
      @dependencies = {}
    end

    def configure(&block)
      instance_exec(&block)
    end

    def each(&block)
      @dependencies.each(&block)
    end

    # @param name [String]
    # @param klass [Class]
    # @return [void]
    def register(type, klass = nil, &block)
      @dependencies[type] = klass&.new || block.call
    end

    # @!macro
    #   @param type [Object]
    #   @param _ [Object]
    #   @return [$2]
    def use(type, _ = nil)
      @dependencies[type]
    end
  end
end
