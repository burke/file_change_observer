# coding: utf-8
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "file_change_observer/version"

Gem::Specification.new do |spec|
  spec.name          = "file_change_observer"
  spec.version       = FileChangeObserver::VERSION
  spec.authors       = ["Burke Libbey"]
  spec.email         = ["burke.libbey@shopify.com"]

  spec.summary       = %q{Tar files changed by a block}
  spec.description   = %q{Tar files changed by a block.}
  spec.homepage      = "https://github.com/burke/file_change_observer"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = []
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.15"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "minitest", "~> 5.0"

  spec.add_runtime_dependency "rb-fsevent", ">= 0.10.0"
end
