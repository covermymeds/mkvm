# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'mkvm/version'

Gem::Specification.new do |spec|
  spec.name          = "mkvm"
  spec.version       = MKVM::VERSION
  spec.authors       = ["CoverMyMeds"]
  spec.email         = ["smerrill@covermymeds.com", "dsajner@covermymeds.com", "dmorris@covermymeds.com"]
  spec.summary       = %q{Interact with VMWare to build or remove VMs}
  spec.description   = %q{Wraps rbvmomi to interact with the VMWare API to build or remove VMs.}
  spec.homepage      = "http://www.covermymeds.com"
  spec.license       = "MIT"

  spec.files         = Dir.glob("{lib,plugins,isolinux}/**/*") + %w(README.md mkvm.rb rmvm.rb)
  spec.executables   = ["mkvm.rb", "rmvm.rb"]
  spec.require_paths = ["lib", "plugins", "isolinux", "iso"]

  spec.add_dependency 'rbvmomi', '>= 1.8.2'

end
