#!/usr/bin/env ruby
# Copyright 2014, CoverMyMeds, LLC
# Author: Doug Morris <dmorris@covermymeds.com>/Scott Merrill <smerrill@covermymeds.com>
# Released under the terms of the GPL version 2
#   http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt
require "erb"
require "io/console"
require "ipaddr"
require "net/https"
require "xmlrpc/client"
require "openssl"
require "uri"
require "net/smtp"
require "optparse"
require "rbvmomi"
require "rubygems"
require "yaml"
require "json"

# establish a couple of sane default values
options = {
  :username   => ENV["USER"],
  :insecure   => true,
  :vmware     => true,
  :satellite  => true,
  :puppet     => true,
  :puppet_env => "Production",
  :ipam       => true,
}

# read config from mkvm.yaml, if it exists
if File.exists? Dir.home + "/.mkvm.yaml"
  user_options = YAML.load_file(Dir.home + "/.mkvm.yaml")
  options.merge!(user_options)
end

$debug = false
exit_code = 0

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
  opts.banner = "Usage: #{_self} [options] fqdn"
  opts.separator ""
  opts.separator "VSphere options:"
  opts.on( "--no-vmware", "Do not remove from VMware") do |x|
    options[:vmware] = false
  end
  opts.on( "-u", "--user USER", "vSphere user name (#{options[:username]})") do |x|
    options[:username] = x
  end
  opts.on( "-p", "--password PASSWORD", "vSphere password") do |x|
    options[:password] = x
  end
  opts.on( "-H", "--host HOSTNAME", "vSphere host (#{options[:host]})") do |x|
    options[:host] = x
  end
  opts.on( "-D", "--dc DATACENTER", "vSphere data center (#{options[:dc]})") do |x|
    options[:dc] = x
  end
  opts.separator ""

  opts.separator "Satellite options:"
  opts.on("--no-satellite", "Do not remove from Satellite") do |x|
    options[:satellite] = false
  end
  opts.on("--sat-url URL", "Satellite server URL (#{options[:sat_url]})") do |x|
    options[:sat_url] = x
  end
  opts.on("--sat-username USERNAME", "Satellite user name (#{options[:sat_username] or options[:username]})") do |x|
    options[:sat_username] = x
  end
  opts.on("--sat-password PASSWORD", "Satellite password") do |x|
    options[:sat_password] = x
  end
  opts.separator ""

  opts.separator "Puppet options:"
  opts.on("--no-puppet", "Do not remove from puppet") do |x|
    options[:puppet] = false
  end
  opts.on("--puppetmaster-url URL", "Puppetmaster server URL (#{options[:puppetmaster_url]})") do |x|
    options[:puppetmaster_url] = x
  end
  opts.on("--puppetdb-url URL", "PuppetDB server URL (#{options[:puppetdb_url] or options[:puppetmaster_url]})") do |x|
    options[:puppetdb_url] = x
  end
  opts.on("--puppet-env ENV", "Server's Puppet environment (#{options[:puppet_env]})") do |x|
    options[:puppet_env] = x
  end
  opts.on("--puppet-cert CERT", "Certificate signed by Puppet CA (#{options[:puppet_cert]})") do |x|
    options[:puppet_cert] = x
  end
  opts.on("--puppet-key KEY", "Key for puppet-cert (#{options[:puppet_key]})") do |x|
    options[:puppet_key] = x
  end
  opts.separator ""

  opts.separator "IPAM options:"
  opts.on("--no-ipam", "Do not remove from IPAM") do |x|
    options[:ipam] = false
  end
  opts.on( "--del-uri URL", "Delete URI for IPAM system (#{options[:del_uri]})") do |x|
    options[:del_uri] = x
  end
  opts.on( "--apiapp APIAPP", "Name of api application to use (#{options[:apiapp]})") do |x|
    options[:apiapp] = x
  end
  opts.on( "--apitoken APITOKEN", "Token to use with the api application (#{options[:apitoken]})") do |x|
    options[:apitoken] = x
  end
  opts.separator ""

  opts.separator "Email options"
  opts.on( "--smtp SERVER", "SMTP server to use to send email (#{options[:mail_server]})") do |x|
    options[:smtp_server] = x
  end
  opts.on( "--from ADDRESS", "Email address from which to send email (#{options[:mail_from]})") do |x|
    options[:smtp_server] = x
  end
  opts.on( "--to ADDRESS", "Email address to which to send email (#{options[:mail_to]})") do |x|
    options[:smtp_server] = x
  end
  opts.separator ""

  opts.separator "General options:"
  opts.on( "--[no-]insecure", "Do not validate SSL certificates (#{options[:insecure]})") do |x|
    options[:insecure] = x
  end
  opts.on( "-v", "--debug", "Verbose output") do
    $debug = true
  end
  opts.on( "-h", "--help", "Display this screen" ) do
    puts opts
    exit
  end
end

# actully parse the command line arguments.
optparse.parse!


# What's left over should be the fqdn.
# But let's be cautious
if ARGV.count == 0
  abort "Missing fqdn!"
elsif ARGV.count > 1
  abort "Just one fqdn, please!"
end

# Groovy.
options[:fqdn] = ARGV[0].downcase
options[:hostname] = options[:fqdn].split('.')[0]

# we don't want to require passords on the command line
if not options[:password]
  print "Password: "
  options[:password] = STDIN.noecho(&:gets).chomp
  puts ""
end

if options[:vmware]
  VIM = RbVmomi::VIM
  vim = VIM.connect( { :user => options[:username], :password => options[:password], :host => options[:host], :insecure => options[:insecure] } ) or abort $!
  dc = vim.serviceInstance.find_datacenter(options[:dc]) or abort "vSphere data center #{options[:dc]} not found"
  
  debug( "INFO", "Connected to datacenter #{options[:dc]}" )
  
  vm = dc.find_vm(options[:fqdn]) or abort "Unable to locate #{options[:fqdn]} in data center #{options[:dc]}"
  pwrs = vm.runtime.powerState
  
  if pwrs == "poweredOn"
    puts "Powering off #{options[:fqdn]}"
    begin
      vm.PowerOffVM_Task.wait_for_completion
    rescue Exception => msg
      puts "Failed to poweroff #{options[:fqdn]}: #{msg}"
      exit_code += 1
    end
  end
  
  puts "Destroying #{options[:fqdn]}"
  begin
    vm.Destroy_Task.wait_for_completion
    puts "#{options[:fqdn]} has been destroyed/removed from VMware."
  rescue Exception => msg
    puts "Failed to destroy #{options[:fqdn]} from VMware: #{msg}."
    exit_code += 1
  end
end

if options[:satellite]
  puts "Removing #{options[:fqdn]} from Satellite...."

  # If we weren't given different satellite credentials, use vSphere credentials
  options[:sat_username] = options[:sat_username] ? options[:sat_username] : options[:username]
  options[:sat_password] = options[:sat_password] ? options[:sat_password] : options[:password]

  begin
    client = XMLRPC::Client.new2(options[:sat_url])

    # Disable certificate verification
    #   # TODO: Support for secure connections?
    client.instance_variable_get("@http").verify_mode = OpenSSL::SSL::VERIFY_NONE

    # Auth
    key = client.call("auth.login", options[:sat_username], options[:sat_password])
    
    # Generate a unique list of systems. This requires the removal of the last_checkin element since 
    # that is always unique.
    systems = (client.call("system.search.hostname", key, options[:hostname]) +
               client.call("system.search.hostname", key, options[:fqdn])).each {|system| system.delete('last_checkin')}.uniq

    # Ensure that results were found from Satellite
    if systems.any?
      systems.each do |system|
        # system.search.hostname will return non-exact matches. Make sure the system hostname is an exact match for
        # either fqdn or short hostname
        if [options[:fqdn], options[:hostname]].include? system["hostname"]
          client.call("system.deleteSystem", key, system["id"])
        end
      end
      puts "Server '#{options[:fqdn]}' deleted from Satellite."
    else
      puts "Unable to match '#{options[:fqdn]}' in Satellite. Manual deletion required."
      exit_code += 1
    end

  rescue Exception => msg
    puts "Error deleting system from Satellite: #{msg}"
    exit_code += 1
  end
end

if options[:puppet]
  puts "Removing #{options[:fqdn]} from Puppet...."

  # Defaults to build URLs
  puppetmaster_default_port = 8140
  puppetmaster_default_path = "/puppet-ca/v1/certificate_status/#{options[:fqdn]}"
  puppetdb_default_port = 8081
  puppetdb_default_path = "/pdb/cmd/v1"

  # If a puppetdb_url wasn't given, just use the puppetmaster_url since most installations are one-node
  options[:puppetdb_url] = options[:puppetdb_url] ? options[:puppetdb_url] : options[:puppetmaster_url]

  # Generate URI object for puppet URLs
  puppetmaster_url = URI.parse(URI.escape(options[:puppetmaster_url]))
  puppetdb_url = URI.parse(URI.escape(options[:puppetdb_url]))

  # TODO: Clean this up
  # Set default port if none were provided
  puppetmaster_url.port = [80, 443].include?(puppetmaster_url.port) ? puppetmaster_default_port : puppetmaster_url.port
  puppetdb_url.port = [80, 443].include?(puppetdb_url.port) ? puppetdb_default_port : puppetdb_url.port

  # Set default path if none were provided
  puppetmaster_url.path = puppetmaster_url.path.empty? ? puppetmaster_default_path : puppetmaster_url.path
  puppetdb_url.path = puppetdb_url.path.empty? ? puppetdb_default_path : puppetdb_url.path

  # Set our environment in the puppetmaster url query
  puppetmaster_url.query = "environment=#{options[:puppet_env]}"

  # Load Certificate & key objects
  if options[:puppet_cert]
    options[:puppet_cert] = OpenSSL::X509::Certificate.new File.read options[:puppet_cert]
  end
  if options[:puppet_key]
    options[:puppet_key] = OpenSSL::PKey::RSA.new File.read options[:puppet_key]
  end

  #
  # PUPPETDB DEACTIVATE REQUEST
  #
  # Setup http object
  http = Net::HTTP.new(puppetdb_url.host, puppetdb_url.port)
  http.use_ssl = true
  http.ssl_version = :TLSv1
  http.cert = options[:puppet_cert]
  http.key = options[:puppet_key]

  # Disable cerificate verification
  # TODO: Support for secure connections?
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE

  # Build HTTP PUT request
  request = Net::HTTP::Post.new(puppetdb_url.path, initheader = {
    "Content-Type" => "application/json",
    "Accept" => "application/json"
  })
  request.body = {
    "command" => "deactivate node",
    "version" => 3,
    "payload" => {"certname" => options[:fqdn]},
  }.to_json

  # Send request to API
  response = http.start {|http_request| http_request.request(request)}
  if not response.code.start_with? "2"
    puts "There was an error with your PuppetDB request: #{response.code}"
    exit_code += 1
  else
    puts "Server '#{options[:fqdn]}' deactivated in PuppetDB. Request uuid: '#{JSON.parse(response.body)["uuid"]}'"
  end

  #
  # PUPPET CERT REVOKE/DELETE REQUESTS
  #
  # TODO: possible to reuse previous Net::HTTP object?
  # Setup http object
  http = Net::HTTP.new(puppetmaster_url.host, puppetmaster_url.port)
  http.use_ssl = true
  http.ssl_version = :TLSv1
  http.cert = options[:puppet_cert]
  http.key = options[:puppet_key]

  # Disable cerificate verification
  # TODO: Support for secure connections?
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE

  # Build HTTP PUT & DELETE requests
  requests = []

  # PUT Request to revoke the cert
  revoke_request = Net::HTTP::Put.new(puppetmaster_url.path, initheader = {"Content-Type" => "text/pson"})
  revoke_request.body = {"desired_state" => "revoked"}.to_json
  requests << revoke_request

  # DELETE request to delete the cert
  delete_request = Net::HTTP::Delete.new(puppetmaster_url.path, initheader = {"Accept" => "pson"})
  requests << delete_request

  success = true
  http.start do |http_request|
    requests.each do |r|
      response = http_request.request r

      if not response.code.start_with? "2"
        puts "There was an error with your Puppet API request: #{response.code}"
        success = false
      end
    end
  end

  if success
    puts "Puppet certificates for server '#{options[:fqdn]}' revoked & removed"
  else
    puts "Some or all of the Puppet removal failed."
    exit_code += 1
  end
end

if options[:ipam]
  puts "Removing #{options[:fqdn]} from IPAM...."

  # Send delete request to phpipam system
  uri = options[:del_uri].gsub(/APIAPP|APITOKEN|HOSTNAME/, {"APIAPP" => options[:apiapp], "APITOKEN" => options[:apitoken], "HOSTNAME" => options[:fqdn],})
  uri = URI.escape(uri)
  uri = URI.parse(uri)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  request = Net::HTTP::Get.new(uri.request_uri)
  response = http.request(request)
  if response.code != "200"
    puts "There was an error with your IPAM request: #{response.code}"
    exit_code += 1
  else
    del_response = response.body
    puts "#{del_response}"
  end
end


msg_body = <<END_MSG
From: #{options[:mail_from]}
To: #{options[:mail_to]}
Subject: #{options[:fqdn]} has been deleted by rmvm.
END_MSG

# only send email if we have an SMTP server, a from address, and a to address
if options[:mail_server] and options[:mail_from] and options[:mail_to]
  Net::SMTP.start(options[:mail_server], 25) do |smtp|
    smtp.send_message msg_body, options[:mail_from], options[:mail_to]
  end
end

exit exit_code
