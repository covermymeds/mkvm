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
require "net/smtp"
require 'optparse'
require 'rbvmomi'
require 'rubygems'
require "uri"
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
  opts.banner = "Usage: #{_self} [options] hostname"
  opts.separator ''
  opts.separator 'VSphere options:'
  opts.on( '-u', '--user USER', "vSphere user name (#{options[:username]})") do |x|
    options[:username] = x
  end
  opts.on( '-p', '--password PASSWORD', 'vSphere password') do |x|
    options[:password] = x
  end
  opts.on( '-H', '--host HOSTNAME', "vSphere host (#{options[:host]})") do |x|
    options[:host] = x
  end
  opts.on( '-D', '--dc DATACENTER', "vSphere data center (#{options[:dc]})") do |x|
    options[:dc] = x
  end
  opts.on( '--[no-]insecure', "Do not validate vSphere SSL certificate (#{options[:insecure]})") do |x|
    options[:insecure] = x
  end
  opts.separator 'Email options'
  opts.on( '--smtp server', "SMTP server to use to send email (#{options[:mail_server]})") do |x|
    options[:smtp_server] = x
  end
  opts.on( '--from address', "Email address from which to send email (#{options[:mail_from]})") do |x|
    options[:smtp_server] = x
  end
  opts.on( '--to address', "Email address to which to send email (#{options[:mail_to]})") do |x|
    options[:smtp_server] = x
  end
  opts.separator 'IPAM options:'
  opts.on( '--del-uri uri', "Delete URI for IPAM system (#{options[:del_uri]})") do |x|
    options[:del_uri] = x
  end
  opts.on( '--apiapp apiapp', "Name of api application to use (#{options[:apiapp]})") do |x|
    options[:apiapp] = x
  end
  opts.on( '--apitoken apitoken', "Token to use with the api application (#{options[:apitoken]})") do |x|
    options[:apitoken] = x
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


# What's left over should be the hostname.
# But let's be cautious
if ARGV.count == 0
  abort "Missing hostname!"
  exit
elsif ARGV.count > 1
  abort "Just one hostname, please!"
end

# Groovy.
hostname = ARGV[0].downcase

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

vm = dc.find_vm(hostname) or abort "Unable to locate #{hostname} in data center #{options[:dc]}"
pwrs = vm.runtime.powerState

# If the vm is powered on, power off and send email
# If the vm is powered off, deletd the vm and remove from IPAM
if pwrs == 'poweredOn'
  puts "Powering off #{hostname}"
  vm.PowerOffVM_Task.wait_for_completion

  msg_body = <<END_MSG
From: #{options[:mail_from]}
To: #{options[:mail_to]}
Subject: Powered off #{hostname} for deletion from VMware

#{hostname} has been powered off for VMware removal, please run the rmvm.rb script again to destroy vm.


END_MSG

  # only send email if we have an SMTP server, a from address, and a to address
  if options[:mail_server] and options[:mail_from] and options[:mail_to]
    Net::SMTP.start(options[:mail_server], 25) do |smtp|
      smtp.send_message msg_body, options[:mail_from], options[:mail_to]
    end
  end

elsif pwrs == 'poweredOff'
  puts "Destroying #{hostname}"
  vm.Destroy_Task.wait_for_completion
  puts "#{hostname} has been destroyed/removed from VMware."

  puts "Removing #{options[:hostname]} from IPAM...."

  # Send delete request to phpipam system
  uri = options[:del_uri].gsub(/APIAPP|APITOKEN|HOSTNAME/, {'APIAPP' => options[:apiapp], 'APITOKEN' => options[:apitoken], 'HOSTNAME' => options[:hostname],})
  uri = URI.escape(uri)
  uri = URI.parse(uri)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  request = Net::HTTP::Get.new(uri.request_uri)
  response = http.request(request)
  if response.code != "200"
    abort "There was an error with your IPAM request: #{response.code}"
  end
  del_response = response.body
  puts "#{del_response}"
end
