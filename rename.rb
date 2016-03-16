#!/usr/bin/env ruby
# Copyright 2014, CoverMyMeds, LLC
# Author: Doug Morris <dmorris@covermymeds.com>/Scott Merrill <smerrill@covermymeds.com>
# Released under the terms of the GPL version 2
#   http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt
gem 'rbvmomi', '1.6.0'
require "erb"
require 'io/console'
require "ipaddr"
require "net/https"
require 'optparse'
require 'rbvmomi'
require 'rubygems'
require 'yaml'

# establish a couple of sane default values
options = {
  :username   => ENV['USER'],
  :insecure   => true,
}

# read config from mkvm.yaml, if it exists
if File.exists? Dir.home + "/.mkvm.yaml"
  user_options = YAML.load_file(Dir.home + "/.mkvm.yaml")
  options.merge!(user_options)
end


### MAIN PROGRAM ###
# parse our command-line options
optparse = OptionParser.new do|opts|
  opts.banner = "Usage: rename.rb [options] template_name"
  opts.separator ''
  opts.separator 'VSphere options:'
  opts.on( '-u', '--user USER', "vSphere user name (#{options[:username]})") do |x|
    options[:username] = x
  end
  opts.on( '-p', '--password PASSWORD', 'vSphere password') do |x|
    options[:password] = x
  end
  opts.on( '-s', '--source HOSTNAME', "source host to rename (#{options[:source_vm]})") do |x|
    options[:source_vm] = x
  end
  opts.on( '-n', '--newname HOSTNAME', "new name of the host (#{options[:new_name]})") do |x|
    options[:new_name] = x
  end
  opts.on( '-H', '--host HOSTNAME', "vSphere hostname (#{options[:host]})") do |x|
    options[:host] = x
  end
  opts.on( '-D', '--dc DATACENTER', "vSphere data center (#{options[:dc]})") do |x|
    options[:dc] = x
  end
  opts.on( '--[no-]insecure', "Do not validate vSphere SSL certificate (#{options[:insecure]})") do |x|
    options[:insecure] = x
  end
  opts.separator ''
  opts.separator 'General options:'
  opts.on( '-v', '--debug', 'Verbose output') do
    $debug = true
  end
  opts.on( '-h', '--help', 'Display this screen' ) do
    puts opts
    exit
  end
end

# actully parse the command line arguments.
optparse.parse!

# we don't want to require passords on the command line
if not options[:password]
  print 'Password: '
  options[:password] = STDIN.noecho(&:gets).chomp
  puts ''
end

vim = RbVmomi::VIM.connect( { :user => options[:username], :password => options[:password], :host => options[:host], :insecure => options[:insecure] } ) or abort $!
dc = vim.serviceInstance.find_datacenter(options[:dc]) or abort "vSphere data center #{options[:dc]} not found"
vm = dc.find_vm(options[:source_vm]) or abort "Unable to locate #{options[:source_vm]} in data center #{options[:dc]}"

begin
  vm.ReconfigVM_Task(:spec => RbVmomi::VIM::VirtualMachineConfigSpec(:name=> "#{options[:new_name]}")).wait_for_completion
  dc.find_vm(options[:new_name])
  puts "Successfully renamed #{options[:source_vm]} to #{options[:new_name]}."
rescue
  fail "Failed to rename #{options[:source_vm]}."
end
