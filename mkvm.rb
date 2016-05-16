#!/usr/bin/env ruby
require 'rubygems'
require 'fileutils'
require 'io/console'
require 'optparse'
require 'rbvmomi'
require 'resolv'
require 'socket'
require 'yaml'
require_relative 'lib/mkvm'
require_relative 'lib/vm_drs'

libs = %w[iso kickstart vsphere plugin]
libs.each { |lib| require_relative "lib/#{lib}" }

plugins = []
dir = File.dirname(__FILE__) + '/plugins/*.rb'
Dir[dir].each do |plugin|
  plugins << File.basename(plugin, '.rb').capitalize
  require_relative plugin
end

# create our options hash.
# We'll pass this to each class, and exploit the fact that this
# class will see changes made to this hash in other classes
options = { :debug => false }

# create the objects we'll use
# and merge their default options
ks = Kickstart.new
options.merge!(ks.defaults)
iso = ISO.new
options.merge!(iso.defaults)
vsphere = Vsphere.new
options.merge!(vsphere.defaults)

# plugins may provide defaults, too
plugins.each do |p| 
  plugin_defaults = Kernel.const_get(p).defaults
  options.merge!(plugin_defaults)
end

# read config from .mkvm.yaml, if it exists
if File.exists? Dir.home + "/.mkvm.yaml"
  options.merge!(YAML.load_file(Dir.home + "/.mkvm.yaml"))
end

# command line options are defined in each module
opts = OptionParser.new
opts.banner = 'Usage: mkvm.rb [options] hostname'
opts.separator ''

# these classes can modify the opts and options variables in this scope
ks.optparse(opts, options)
iso.optparse(opts, options)
vsphere.optparse(opts, options)

# let plugins add options, too
plugins.each { |p| Kernel.const_get(p).optparse(opts, options) }
# and some useful general options
opts.separator 'General options:'
opts.on( '--extra "ONE=1 TWO=2"', 'extra args to pass to boot line or to extraConfigs in the case of VM clone') do |x|
  options[:extra] = x
end
opts.on('-v', '--debug', 'Enable verbose output') do |x|
  options[:debug] = true
end
opts.on('-h', '--help', 'This help message') do
  puts opts
  exit
end

opts.parse!

# What's left over should be the hostname.
# But let's be cautious
if ARGV.count == 0
  abort "Missing hostname!"
  exit
elsif ARGV.count > 1
  abort "Just one hostname, please!"
end

options[:hostname] = ARGV[0].downcase

# we let plugins run their validation processes first
# so that they might set values required by the core modules
# sort was added below to insure autoip runs before ip in plugins
plugins.sort.each { |p| Kernel.const_get(p).pre_validate(options) }

iso.validate(options)
vsphere.validate(options)
ks.validate(options)

# and we let plugins run another validation after the core modules
plugins.each { |p| Kernel.const_get(p).post_validate(options) }

# for each of our main tasks, we allow plugins to execute
# both before and after, to afford the most flexibility
if ! options[:clone]
  plugins.each { |p| Kernel.const_get(p).pre_iso(options) }
  iso.execute(options)
  plugins.each { |p| Kernel.const_get(p).post_iso(options) }
end

plugins.each { |p| Kernel.const_get(p).pre_vm(options) }
vsphere.execute(options)
plugins.each { |p| Kernel.const_get(p).post_vm(options) }
