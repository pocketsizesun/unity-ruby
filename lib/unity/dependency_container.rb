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
    def register(name, klass = nil, &block)
      @dependencies[name] = klass&.new || block.call
    end

    # @param type [Object]
    # @return [Object]
    def use(name)
      @dependencies[name]
    end
  end
end
