#!/usr/bin/env ruby
# Copyright 2014, CoverMyMeds, LLC
# Author: Scott Merrill <smerrill@covermymeds.com>
# Released under the terms of the GPL version 2
#   http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt
require 'rubygems'
gem 'rbvmomi', '1.6.0'
require 'fileutils'
require 'io/console'
require 'optparse'
require 'rbvmomi'
require 'resolv'
require 'socket'
require 'yaml'

# establish a couple of sane default values
options = {
	'username'   => ENV['USER'],
	'insecure'   => true,
	'dir'        => '.',
	'make_iso'   => true,
	'upload_iso' => true,
	'make_vm'    => true,
	'power_on'   => true,
	'vlan'       => 'Production',
}

# read config from mkvm.yaml, if it exists
if File.exists? Dir.home + "/.mkvm.yaml"
	user_options = YAML.load_file(Dir.home + "/.mkvm.yaml")
	options.merge!(user_options)
end

templates = {
	'tiny'   => [1,  512, 14680064],
	'small'  => [1, 1024, 15728640],
	'medium' => [1, 2048, 15728640],
	'large'  => [2, 4096, 15728640],
	'xlarge' => [2, 8192, 15728640],
}

hostname = nil
template = nil
custom = nil
$debug = false

## STOP EDITING ##

# enable debug output
def debug(prefix, msg)
	if $debug
		puts "#{prefix}: #{msg}"
	end
end

# return the IP address of the given hostname
def get_address( host )
	Resolv.getaddress( host )
rescue Resolv::ResolvError
	false
end

# return the FQDN from a DNS lookup
def get_fqdn( shortname )
	Socket.gethostbyname(shortname).first
rescue SocketError
	false
end

# return the DNS name of the given IP address
def get_name( ip )
	Resolv.getname( ip )
rescue Resolv::ResolvError
	false
end

# assume the gateway is always .1 of the given network
def get_gateway_address( ip )
	octets = ip.split('.')
	octets[-1] = '1'
	return octets.join('.')
end

### MAIN PROGRAM ###
_self = File.basename($0)
# parse our command-line options
optparse = OptionParser.new do|opts|
	opts.banner = "Usage: #{_self} [options] hostname\n\n"
	opts.on( '-u', '--user USER', "vSphere user name (#{options['username']})") do |x|
		options['username'] = x
	end
	opts.on( '-p', '--password PASSWORD', 'vSphere password') do |x|
		options['password'] = x
	end
	opts.on( '-H', '--host HOSTNAME', "vSphere host (#{options['host']})") do |x|
		options['host'] = x
	end
	opts.on( '-D', '--dc DATACENTER', "vSphere data center (#{options['dc']})") do |x|
		options['dc'] = x
	end
	opts.on( '-C', '--cluster CLUSTER', "vSphere cluster (#{options['cluster']})") do |x|
		options['cluster'] = x
	end
	opts.on( '--[no-]insecure', "Do not validate vSphere SSL certificate (#{options['insecure']})") do |x|
		options['insecure'] = x
	end
	opts.on( '--datastore DATASTORE', "vSphere datastore regex to use (#{options['ds_regex']})") do |x|
		options['ds_regex'] = x
	end
	opts.on( '--isostore ISOSTORE', "vSphere ISO store to use (#{options['iso_store']})") do |x|
		options['isostore'] = x
	end
	opts.on( '-i', '--ip ADDRESS', 'IP address') do |x|
		options['ip'] = x
	end
	opts.on( '-g', '--gateway GATEWAY', 'Gateway address') do |x|
		options['gateway'] = x
	end
	opts.on( '-m', '--netmask NETMASK', "Subnet mask (#{options['netmask']})") do |x|
		options['netmask'] = x
	end
	opts.on( '-d', '--dns DNS1{,DNS2,...}', "DNS server(s) to use (#{options['dns']})") do |x|
		options['dns'] = x
	end
	opts.on( '--app-env APP_ENV', "APP_ENV (#{options['app_env']})") do |x|
		options['app_env'] = x
	end
	opts.on( '--app-id APP_ID', 'APP_ID') do |x|
		options['app_id'] = x
	end
	opts.on( '--url URL', "Kickstart URL (#{options['url']})") do |x|
		options['url'] = x
	end
	opts.on( '--dir DIR', "Directory containing isolinux template (#{options['dir']})") do |x|
		options['dir'] = x
	end
	opts.on( '--domain DOMAIN', "DNS domain to append to hostname (#{options['domain']})") do |x|
		options['domain'] = x
	end
	opts.on( '-t', '--template TEMPLATE', "VM template: tiny, small, medium, large, xlarge") do |x|
		template = x
	end
	opts.on( '--custom cpu,mem,sda', Array, 'CPU, Memory, and /dev/sda for VM' ) do |x|
		custom = x
	end
	opts.on( '--sdb [KB]', 'Size of optional /dev/sdb in KB (10485760)' ) do |x|
		options['sdb'] = x || 10485760
	end
	opts.on( '--vlan VLAN', "VLAN (#{options['vlan']})") do |x|
		options['vlan'] = x
	end
	opts.on( '--[no-]iso', "Build ISO (#{options['make_iso']})") do |x|
		options['make_iso'] = x
	end
	opts.on( '--[no-]upload', "Upload the ISO to the ESX cluster (#{options['upload_iso']})") do |x|
		options['upload_iso'] = x
	end
	opts.on( '--[no-]vm', "Build the VM (#{options['make_vm']})") do |x|
		options['make_vm'] = x
	end
	opts.on( '--[no-]power', "Power on the VM after building it (#{options['power_on']})") do |x|
		options['power_on'] = x
	end
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
# And let's make sure it's a shortname, not an FQDN
if hostname =~ /\./
	abort 'The hostname should not contain dots'
end

# perform a few sanity checks on the network parameters
options['ip'] = get_address( hostname ) unless options['ip']
abort "ERROR: No IP supplied, and no DNS for #{hostname}" unless options['ip']
options['gateway'] = get_gateway_address( options['ip'] ) unless options['gateway']

abort "ERROR: Invalid IP address #{options['ip']}" unless options['ip'] =~ Resolv::IPv4::Regex

mask_regex = /^[1-2]{1}[2,4,5,9]{1}[0,2,4,5,8]{1}\.[0-2]{1}[0,2,4,5,9]{1}[0,2,4,5,8]{1}\.[0-2]{1}[0,2,4,5,9]{1}[0,2,4,5,8]{1}\.[0-9]{1,3}$/
	abort "ERROR: Invalid subnet mask #{options['subnet']}" unless options['netmask'] =~ mask_regex

abort "ERROR: Invalid gateway #{options['gateway']}" unless options['gateway'] =~ Resolv::IPv4::Regex
abort "ERROR: IP cannot match gateway!" unless options['ip'] != options['gateway']

# compare DNS with the network parameters
resolved_ip = get_address( hostname )
if resolved_ip and (resolved_ip != options['ip'])
	debug( 'WARN', "#{options['ip']} does not match DNS for #{hostname}" )
end
fqdn = get_fqdn( hostname ) || "#{hostname}.#{options['domain']}"
resolved_name = get_name( options['ip'] )
if resolved_name and (resolved_name != fqdn)
	debug( 'WARN', "#{options['ip']} already assigned to #{resolved_name}" )
end
debug( 'INFO', "IP: #{options['ip']}" )
debug( 'INFO', "Netmask: #{options['netmask']}" )
debug( 'INFO', "Gateway: #{options['gateway']}" )

# we need a template selection or custom definition, but not both
abort '-t or --custom is required' unless template or custom
if template and custom
	abort '-t and --custom are mutually exclusive'
end

if template
	options['cpu'], options['mem'], options['sda'] = templates[template]
else
	options['cpu'], options['mem'], options['sda'] = custom
end
debug( 'INFO', "CPU: #{options['cpu']}" )
debug( 'INFO', "Mem: #{options['mem']}" )
debug( 'INFO', "sda: #{options['sda']}" )
debug( 'INFO', "sdb: #{options['sdb']}" )

# TODO: validate the VLAN
debug( 'INFO', "VLAN: #{options['vlan']}" )

# build the ISO
if options['make_iso']
	isoname = "#{hostname}.iso"
	tmp_dir = "#{options['dir']}/tmp/#{hostname}"
	# TODO: handle exceptions
	FileUtils.mkdir_p tmp_dir

	# create the ISO template directory
	FileUtils.cp_r "#{options['dir']}/isolinux", tmp_dir

	# build our kickstart line
	ks_line="ks=#{options['url']} noverifyssl ksdevice=eth0 ip=#{options['ip']} netmask=#{options['netmask']} gateway=#{options['gateway']} hostname=#{hostname}.#{options['domain']} dns=#{options['dns']} APP_ENV=#{options['app_env']}"
	# add the APP_ID, if one was supplied
	ks_line += " APP_ID=#{options['app_id']}" if options['app_id']

	text = IO.read( "#{tmp_dir}/isolinux/isolinux.cfg" )
	text.gsub!(/KICKSTART_PARMS/, ks_line)
	IO.write( "#{tmp_dir}/isolinux/isolinux.cfg", text )

	system( "mkisofs -quiet -o #{options['dir']}/#{isoname} -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -J -R -V '#{hostname}' #{tmp_dir}" )

	# clean up after ourselves
	FileUtils.rm_rf "#{tmp_dir}"
	FileUtils.chmod_R 0755, "#{options['dir']}/#{isoname}"

	debug( 'INFO', "#{options['dir']}/#{isoname} created" )
end

# stop here if we're not doing anything with ESX
# - no sense asking for a password we won't use
if not options['upload_iso'] and not options['make_vm']
	exit
end

# we don't want to require passords on the command line
if not options['password']
	print 'Password: '
	options['password'] = STDIN.noecho(&:gets).chomp
	puts ''
end

VIM = RbVmomi::VIM
# TODO: handle exceptions here
vim = VIM.connect( { :user => options['username'], :password => options['password'], :host => options['host'], :insecure => options['insecure'] } ) or abort $!
dc = vim.serviceInstance.find_datacenter(options['dc']) or abort "vSphere data center #{options['dc']} not found"

debug( 'INFO', "Connected to datacenter #{options['dc']}" )

# upload the ISO as needed
if options['upload_iso']
	# get the ISO datastore
	isostore = dc.find_datastore(options['iso_store'])

	debug( 'INFO', "Uploading #{hostname}.iso to #{options['iso_store']}" )
	isostore.upload "/#{hostname}.iso", "#{options['dir']}/#{hostname}.iso"
end

cluster = dc.hostFolder.children.find { |x| x.name == options['cluster'] } or abort "vSphere cluster #{options['cluster']} not found"

debug( 'INFO', "Found VMware cluster #{options['cluster']}" )

# want to select a random datastore ?
# datastore = dc.datastore.find_all { |x| x.name =~ options['datastore'] }.shuffle[0]
# select the datastore with the most available space
datastore = dc.datastore.find_all { |x| x.name =~ /#{options['ds_regex']}/ }.max_by{ |i| i.info.freeSpace }.name

	debug( 'INFO', "Selected datastore #{datastore}" )

# this hash is yucky, but that's how VMware rolls
time = Time.new
annotation = "Created by " + options['username'] + " on " + time.strftime("%Y-%m-%d at %H:%M %p")
vm_cfg = {
	:name => hostname,
	:annotation => annotation,
	:guestId => 'rhel6_64Guest',
	:files => { :vmPathName => "[#{datastore}]" },
	:numCPUs => options['cpu'],
		:memoryMB => options['mem'],
		:deviceChange => [
			{
		:operation => :add,
		:device => VIM.ParaVirtualSCSIController(
			:key => 100,
			:busNumber => 0,
			:sharedBus => :noSharing
	)
	},
		{
		:operation => :add,
		:fileOperation => :create,
		:device => VIM.VirtualDisk(
			:key => 0,
			:backing => VIM.VirtualDiskFlatVer2BackingInfo(
				:fileName => "[#{datastore}]",
				:diskMode => :persistent,
					:thinProvisioned => false,
	),
	:controllerKey => 100,
	:unitNumber => 0,
	:capacityInKB => options['sda'],
	)
	},
		{
		:operation => :add,
		:device => VIM.VirtualCdrom(
			:key => -2,
			:backing => VIM.VirtualCdromIsoBackingInfo(
				:fileName => "[#{options['iso_store']}] #{hostname}.iso",
	),
		:connectable => VIM.VirtualDeviceConnectInfo(
			:allowGuestControl => true,
			:connected => true,
			:startConnected => true,
	),
	:deviceInfo => {
		:label => 'CD/DVD drive 1',
		:summary => "ISO [#{options['iso_store']}] #{hostname}.iso",
	},
		:controllerKey => 200,
		:unitNumber => 0,
	),
	},
	{
		:operation => :add,
		:device => VIM.VirtualVmxnet3(
			:key => 0,
			:deviceInfo => {
		:label => 'Network Adapter 1',
		:summary => options['vlan']
	},
		:backing => VIM.VirtualEthernetCardNetworkBackingInfo(
			:deviceName => options['vlan']
	),
		:addressType => 'generated'
	)
	}
	],
}

	if options['sdb']
		sdb = {
			:operation => :add,
			:fileOperation => :create,
			:device => VIM.VirtualDisk(
				:key => 1,
				:backing => VIM.VirtualDiskFlatVer2BackingInfo(
					:fileName => "[#{datastore}]",
					:diskMode => :persistent,
						:thinProvisioned => false,
		),
		:controllerKey => 100,
		:unitNumber => 1,
		:capacityInKB => options['sdb'],
		)
		}
		vm_cfg[:deviceChange] << sdb
	end

# stop here if --no-vm
if not options['make_vm']
	abort "--no-vm selected. Terminating"
end
vmFolder = dc.vmFolder
rp = cluster.resourcePool
debug( 'INFO', "Building #{hostname} VM now" )
_vm = vmFolder.CreateVM_Task( :config => vm_cfg, :pool => rp).wait_for_completion
if options['power_on']
	_vm.PowerOnVM_Task.wait_for_completion
end
puts "Don't forget to create DRS rules!"
