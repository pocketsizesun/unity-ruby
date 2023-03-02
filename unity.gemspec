require_relative 'lib/unity/version'

Gem::Specification.new do |spec|
  spec.name          = "unity"
  spec.version       = Unity::VERSION
  spec.authors       = ["Julien D."]
  spec.email         = ["julien@pocketsizesun.com"]

  spec.summary       = %q{Application core library}
  spec.description   = %q{Base library for all Unity services}
  spec.homepage      = "https://github.com/unitylab-io/unity-ruby"
  spec.license       = "Proprietary"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.3.0")

  # spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/unitylab-io/unity-ruby"
  spec.metadata["changelog_uri"] = "https://github.com/unitylab-io/unity-ruby"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency 'aws-sdk-sns', '~> 1.36'
  spec.add_dependency 'aws-sdk-sqs', '~> 1.34'
  spec.add_dependency 'aws-sdk-dynamodb-attribute-deserializer', '~> 1.0'
  spec.add_dependency 'aws-sdk-dynamodbstreams-event-parser', '~> 1.0'
  spec.add_dependency 'concurrent-ruby', '~> 1.1'
  spec.add_dependency 'http', '~> 4.4'
  spec.add_dependency 'connection_pool', '~> 2.2'
  spec.add_dependency 'rack', '~> 2.2'
  spec.add_dependency 'symbol-fstring'
  spec.add_dependency 'dotenv', '~> 2.7'
  spec.add_dependency 'pry'
  spec.add_dependency 'unity-urn'
  spec.add_dependency 'unity-logger'
  spec.add_dependency 'shoryuken'
  spec.add_development_dependency 'rubocop'
end
