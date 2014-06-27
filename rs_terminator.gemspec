# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'rs_terminator/version'
require 'base64'

Gem::Specification.new do |spec|
  spec.name          = 'rs_terminator'
  spec.version       = RsTerminator::VERSION
  spec.authors       = ['Ryan Cragun']
  encoded_email      = %w(cnlhbkByaWdodHNjYWxlLmNvbQ==)
  spec.email         = encoded_email.map { |e| Base64.decode64(e) }
  spec.summary       = %q(An API Utility for managing cloud resources in a )
  spec.summary       << %q(RightScale account.)
  spec.description   = spec.summary
  spec.homepage      = 'https://github.com/ryancragun/rs_terminator-gem'
  spec.license       = 'MIT'

  spec.files         = `git ls-files`.split($ORS)
  spec.executables   = spec.files.grep(/^bin/) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(/^(test|spec|features)/)
  spec.require_paths = %w(lib)

  spec.add_dependency 'right_api_client'
  spec.add_dependency 'threach'

  spec.add_development_dependency 'bundler', '~> 1.5'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'guard-rspec'
  spec.add_development_dependency 'guard-bundler'
  spec.add_development_dependency 'pry-rescue'
end
