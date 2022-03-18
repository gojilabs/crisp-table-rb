# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'crisp-table/version'

Gem::Specification.new do |spec|
  spec.name          = 'crisp-table'
  spec.version       = CrispTable::VERSION
  spec.authors       = ['Adam Sumner']
  spec.email         = ['adam@gojiabs.com']

  spec.summary       = 'Table library built on top of Rails and React'
  spec.description   = 'This gem allows you to build tables using React for the frontend and Rails on the backend. It includes a simple DSL in Ruby to command React to draw your table appropriately. It supports free-text filtering of rows, sorting rows by column, pagination, and is under active development. Built by Goji Labs in Los Angeles.'
  spec.homepage      = 'http://www.gojilabs.com'
  spec.license       = 'MIT'

  spec.files = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'activerecord', '>= 5.0', '< 7.0'
  spec.add_dependency 'activesupport', '>= 5.0', '< 7.0'
  spec.add_dependency 'react-rails'
end
