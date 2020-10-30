module Unity
  class MiddlewareStack
    Element = Struct.new(:klass, :options)

    def initialize(app)
      @app = app
      @elements = []
    end

    def use(klass, options = {})
      @elements << klass.new(@app, options)
    end

    def each(&block)
      @elements.each(&block)
    end
  end
end
