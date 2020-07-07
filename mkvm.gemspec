# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'mkvm/version'

Gem::Specification.new do |spec|
  spec.name          = "mkvm"
  spec.version       = MKVM::VERSION
  spec.authors       = ["CoverMyMeds"]
  spec.email         = ["smerrill@covermymeds.com", "dsajner@covermymeds.com", "nchowning@covermymeds.com"]
  spec.summary       = %q{Interact with VMWare to build or remove VMs}
  spec.description   = %q{Wraps rbvmomi to interact with the VMWare API to build or remove VMs.}
  spec.homepage      = "https://github.com/covermymeds/mkvm"
  spec.license       = "MIT"

  spec.files         = Dir.glob("{lib,plugins}/**/*") + %w(README.md mkvm.rb rmvm.rb)
  spec.bindir        = '.'
  spec.executables   = ["mkvm.rb", "rmvm.rb", "rename.rb"]
  spec.require_paths = ["lib", "plugins" ]

  spec.add_dependency 'rake'
  spec.add_dependency 'rbvmomi', '>= 1.8.2'
  spec.add_dependency 'rspec', '~> 3.0'

end
