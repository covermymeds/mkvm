# Plugin to auto request an IP from IPAM

require "net/https"
require "uri"
require "json"
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
#    opts.on( '-p', '--password PASSWORD', 'vSphere password') do |x|
#      options[:password] = x
#    end
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
      if (not options[:password])
        print 'Password: '
        options[:password] = STDIN.noecho(&:gets).chomp
        puts ''
      end
      puts "Requesting IP in #{options[:subnet]} vlan"
puts username

      uri = options[:add_uri].gsub(/APIAPP/, {
        'APIAPP' => options[:apiapp],
      })
      uri = uri 
      uri = URI.escape(uri)
      uri = URI.parse(uri.concat("user/"))
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      request = Net::HTTP::Post.new(uri.request_uri)
      request.basic_auth username, options[:password]
      response = http.request(request)
      if response.code != "200"
        abort "There was an error requesting your IP address, IPAM returned code: #{response.code}, message: #{response.body}"
      end
      response_hash = JSON.parse(response.body)
      puts response_hash["code"]
      puts response_hash["data"]["token"]
      auth_token = response_hash["data"]["token"]

      uri = options[:add_uri]
      uri = URI.escape(uri)
      uri = URI.parse(uri.concat("subnets/cidr/#{options[:subnet]}"))
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      request = Net::HTTP::Get.new(uri.request_uri)
      request.add_field("token",  auth_token)
      response = http.request(request)
      if response.code != "200"
        abort "There was an error requesting your IP address, IPAM returned code: #{response.code}, message: #{response.body}"
      end
      response_hash = JSON.parse(response.body)
      puts response_hash["code"]
      puts response_hash["data"][0]["id"]
      subnetId = response_hash["data"][0]["id"]

      uri = options[:add_uri]
      uri = URI.escape(uri)
      uri = URI.parse(uri.concat("subnets/#{subnetId}/first_free/"))
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      request = Net::HTTP::Get.new(uri.request_uri)
      request.add_field("token",  auth_token)
      response = http.request(request)
      if response.code != "200"
        abort "There was an error requesting your IP address, IPAM returned code: #{response.code}, message: #{response.body}"
      end
      response_hash = JSON.parse(response.body)
      puts response_hash["code"]
      puts response_hash["data"]
      new_ip = response_hash["data"]

      uri = options[:add_uri]
      uri = URI.escape(uri)
      uri = URI.parse(uri.concat("addresses/?subnetId=#{subnetId}&ip=#{new_ip}&hostname=#{options[:hostname]}&owner=#{username}"))
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      request = Net::HTTP::Post.new(uri.request_uri)
      request.add_field("token",  auth_token)
      response = http.request(request)
      if response.code != "201"
        abort "There was an error requesting your IP address, IPAM returned code: #{response.code}, message: #{response.body}"
      end
      response_hash = JSON.parse(response.body)
      puts response.body
    end
    exit



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
      if response.body =~ /Error: subnet not in IPAM/
        abort "Error: subnet #{options[:subnet]} not in IPAM"
      end
      options[:ip] = response.body
      puts "Assigned IP: #{options[:ip]}"
#    end
  end
end
