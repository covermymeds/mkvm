#!/usr/bin/env ruby
require 'rubygems'
gem 'rbvmomi', '1.6.0'
require 'fileutils'
require 'io/console'
require 'optparse'
require 'rbvmomi'
require 'resolv'
require 'socket'
require 'yaml'
require_relative 'lib/mkvm'

libs = %w[ISO Kickstart Vsphere Plugin]
libs.each { |lib| require_relative "lib/#{lib}" }

plugins = []
Dir['plugins/*.rb'].each do |plugin|
  plugins << File.basename(plugin, '.rb').capitalize
  require_relative plugin
end

# create our options hash.
options = { :debug => false }

# create the objects we'll use
# and merge their default options
ks = Kickstart.new
options.merge!(ks.defaults)
iso = ISO.new
options.merge!(iso.defaults)
vsphere = Vsphere.new
options.merge!(vsphere.defaults)

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
opts, options = ks.optparse(opts, options)
opts, options = iso.optparse(opts, options)
opts, options = vsphere.optparse(opts, options)
# let plugins add options, too
plugins.each { |p| opts, options = Kernel.const_get(p).optparse(opts, options) }
# and some useful general options
opts.separator 'General options:'
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

options = ks.validate(options)
options = iso.validate(options)
options = vsphere.validate(options)

puts options
