# coding: utf-8
#

require File.expand_path('../lib/version', __FILE__)

Gem::Specification.new do |s|
  s.name          = 'fx-tftp'
  s.version       = TFTP::VERSION
  s.date          = Time.now

  s.summary       = %q{Hackable and ACTUALLY WORKING pure-Ruby TFTP server}
  s.description   = %q{Got carried away a bit with the OOness of the whole thing, so while it will be not the fastest TFTP server it might be the most flexible, at least for pure-Ruby ones.}
  s.license       = 'BSD'
  s.authors       = ['Piotr S. Staszewski']
  s.email         = 'p.staszewski@gmail.com'
  s.homepage      = 'https://github.com/drbig/fx-tftp'

  s.files         = `git ls-files`.split("\n")
  s.test_files    = s.files.grep(%r{^test/})
  s.require_paths = ['lib']

  s.required_ruby_version = '>= 1.9.3'

  s.add_development_dependency 'rubygems-tasks', '~> 0.2'
  s.add_development_dependency 'minitest', '~> 5.4'
end
