# Plugin to auto request an IP from IPAM

require "net/https"
require "uri"
require "ipaddr"

class Autoip < Plugin

  def self.optparse opts, options
    opts.separator 'IPAM options:'
    opts.on( '-s subnet', '--subnet SUBNET', 'subnet in dotted quad, ex: 10.10.2.0') do |x|
      options[:subnet] = x
    end
    opts.on( '--add-uri uri', "URI from which to request an IP address (#{options[:add_uri]})") do |x|
      options[:add_uri] = x
    end
    opts.on( '--apiapp apiapp', "Name of api application to use (#{options[:apiapp]})") do |x|
      options[:apiapp] = x
    end
    opts.on( '--apitoken apitoken', "Token to use with the api application (#{options[:apitoken]})") do |x|
      options[:apitoken] = x
    end
    return opts, options
  end

  def self.pre_validate options
    # if no subnet specified, use the APP_ENV
    if ! options[:ip]
      if ! options[:subnet]
        abort "Subnet (-s) is a required parameter.  This needs to be a dotted quad (ie. 10.1.4.0)" 
      end
      if ! options[:add_uri]
	abort "IPAM uri (--add_uri) is required."
      end
      # Remove any 'DOMAIN\' prefix from the username
      username = options[:username]
      username = username.gsub(/^.+\\(.*)/, '\1')
      puts "Requesting IP in #{options[:subnet]} vlan"

      # Get an IP from our IPAM system
      uri = options[:add_uri].gsub(/SUBNET|HOSTNAME|USER|APIAPP|APITOKEN/, {
                                     'SUBNET'   => options[:subnet],
                                     'HOSTNAME' => options[:hostname],
                                     'USER'     => username,
                                     'APIAPP'   => options[:apiapp],
                                     'APITOKEN' => options[:apitoken],
                                      } )
      uri = URI.escape(uri)
      uri = URI.parse(uri)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      request = Net::HTTP::Get.new(uri.request_uri)
      response = http.request(request)
      if response.code != "200"
        abort "There was an error requesting your IP address, IPAM returned #{response.code}"
      end
      options[:ip] = response.body
      puts "Assigned IP: #{options[:ip]}"
    end
  end
end
