RSpec.describe 'Unity::Application::Operation' do
  it 'should define an Operation' do
    expect do
      class FooOperation < Unity::Operation
        def call(args)
          result = args.fetch('a').to_i + args.fetch('b', 10).to_i
          Output.new(
            result: result
          )
        end
      end
    end.not_to raise_error
  end

  it 'should call an operation and return a result' do
    class FooOperation < Unity::Operation
      def call(args)
        result = args.fetch('number').to_i + 10
        Output.new(
          result: result
        )
      end
    end

    output = FooOperation.call('number' => 20)
    expect(output[:result]).to be(30)
  end
end
