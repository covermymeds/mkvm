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

$debug = false

## STOP EDITING ##


# enable debug output
def debug(prefix, msg)
  if $debug
    puts "#{prefix}: #{msg}"
  end
end

### MAIN PROGRAM ###
_self = File.basename($0)
# parse our command-line options
optparse = OptionParser.new do|opts|
  opts.banner = "Usage: #{_self} [options] template_name"
  opts.separator ''
  opts.separator 'VSphere options:'
  opts.on( '-u', '--user USER', "vSphere user name (#{options[:username]})") do |x|
    options[:username] = x
  end
  opts.on( '-p', '--password PASSWORD', 'vSphere password') do |x|
    options[:password] = x
  end
  opts.on( '-s', '--source HOSTNAME', "source host to clone (#{options[:source_vm]})") do |x|
    options[:source_vm] = x
  end
  opts.on( '-t', '--template HOSTNAME', "name of the template (#{options[:template_vm]})") do |x|
    options[:template_vm] = x
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

VIM = RbVmomi::VIM
# TODO: handle exceptions here
vim = VIM.connect( { :user => options[:username], :password => options[:password], :host => options[:host], :insecure => options[:insecure] } ) or abort $!
dc = vim.serviceInstance.find_datacenter(options[:dc]) or abort "vSphere data center #{options[:dc]} not found"

debug( 'INFO', "Connected to datacenter #{options[:dc]}" )

vm = dc.find_vm(options[:source_vm]) or abort "Unable to locate #{options[:source_vm]} in data center #{options[:dc]}"

# Configure the required params for CloneVM_Task
relocateSpec = VIM.VirtualMachineRelocateSpec
spec = VIM.VirtualMachineCloneSpec(:location => relocateSpec,
                                   :powerOn  => false,
                                   :template => true)

# Clone the VM to a template
begin
  vm.CloneVM_Task(:folder => vm.parent, :name => options[:template_vm], :spec => spec).wait_for_completion
  puts "Successfully cloned #{options[:source_vm]} to #{options[:template_vm]}"
rescue Exception => e
  puts "Failed to clone VM" 
  puts e.message  
  puts e.backtrace.inspect  
end  
