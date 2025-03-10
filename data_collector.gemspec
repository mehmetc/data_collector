
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'data_collector/version'

Gem::Specification.new do |spec|
  spec.name          = 'data_collector'
  spec.version       = DataCollector::VERSION
  spec.authors       = ['Mehmet Celik']
  spec.email         = ['mehmet@celik.be']

  spec.summary       = %q{ETL helper library}
  spec.description   = %q{INPUT, FILTER, OUTPUT data with RULES and code}
  spec.homepage      = 'https://github.com/mehmetc/data_collector'
  spec.license       = 'MIT'

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    #spec.metadata["allowed_push_host"] = "https://github.com/mehmetc/data_collect'"

    spec.metadata['homepage_uri'] = spec.homepage
    spec.metadata['source_code_uri'] = 'https://github.com/mehmetc/data_collect'
    spec.metadata['changelog_uri'] = 'https://github.com/mehmetc/data_collect'
  else
    raise 'RubyGems 2.0 or newer is required to protect against ' \
      'public gem pushes.'
  end

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_runtime_dependency 'activesupport', '~> 8.0'
  spec.add_runtime_dependency 'abbrev'
  spec.add_runtime_dependency 'csv'
  spec.add_runtime_dependency 'mutex_m'
  spec.add_runtime_dependency 'http', '~> 5.2'
  spec.add_runtime_dependency 'json', '~> 2.10'
  spec.add_runtime_dependency 'jsonpath', '~> 1.1'
  spec.add_runtime_dependency 'mime-types', '~> 3.6'
  spec.add_runtime_dependency 'minitar', '= 1.0.2'
  spec.add_runtime_dependency 'nokogiri', '~> 1.18'
  spec.add_runtime_dependency 'nori', '~> 2.7'
  spec.add_runtime_dependency 'iso8601', '~> 0.13'
  spec.add_runtime_dependency 'listen', '~> 3.9'
  spec.add_runtime_dependency 'bunny', '~> 2.23'
  spec.add_runtime_dependency 'bunny_burrow', '~> 1.5'
  spec.add_runtime_dependency 'builder', '~> 3.3'
  spec.add_runtime_dependency 'parse-cron', '~> 0.1'
  spec.add_runtime_dependency 'linkeddata', '~> 3.3'
  spec.add_runtime_dependency 'connection_pool', '~> 2.5'
  spec.add_runtime_dependency 'open-uri-and-write', '~> 0.1.0'
  #spec.add_runtime_dependency 'grpc', '~> 1.61'


  spec.add_development_dependency 'bundler', '~> 2.4'
  spec.add_development_dependency 'minitest', '~> 5.25'
  spec.add_development_dependency 'rake', '~> 13.2'
  spec.add_development_dependency 'webmock', '~> 3.25'
  #spec.add_development_dependency 'grpc-tools', '~> 1.61'
end
