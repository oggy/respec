$:.unshift File.expand_path('lib', File.dirname(__FILE__))
require 'respec/version'

Gem::Specification.new do |gem|
  gem.name          = 'respec'
  gem.version       = Respec::VERSION
  gem.authors       = ['George Ogata']
  gem.email         = ['george.ogata@gmail.com']
  gem.license       = 'MIT'
  gem.summary       = "Rerun failing RSpec examples easily."
  gem.homepage      = 'http://github.com/oggy/respec'

  gem.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  gem.files         = `git ls-files`.split("\n")
  gem.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")

  gem.add_runtime_dependency 'rspec', '>= 2.0.0'
  gem.add_development_dependency 'ritual', '~> 0.4.0'
  gem.add_development_dependency 'temporaries', '~> 0.0.3'
end
