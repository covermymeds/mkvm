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


      # Authenticate and get a token for further operations

      puts "Requesting auth token for #{username}"
      uri = options[:add_uri].gsub(/APIAPP/, {
        'APIAPP' => options[:apiapp],
      })
      uri = uri 
      uri = URI.escape(uri)
      uri = URI.parse(uri.concat("user/"))
      request = Net::HTTP::Post.new(uri.request_uri)
      request.basic_auth username, options[:password]
      retries = [3, 5, 10]
      begin
        response = Net::HTTP.start(uri.host, uri.port, :read_timeout => 5, :use_ssl => true){|http| http.request(request)}
        rescue Net::ReadTimeout
          if delay = retries.shift
            sleep delay
            retry
          else
            abort "The request has timed out, check your username/password and try again"
          end
        end
      if response.code != "200"
        abort "There was an error requesting your IP address, IPAM returned code: #{response.code}, #{JSON.parse(response.body)["message"]}"
      end
      auth_token = JSON.parse(response.body)["data"]["token"]
   
      # Check for an existing host in IPAM

      puts "Checking for existing IP for host #{options[:hostname]}"
      uri = options[:add_uri]
      uri = URI.escape(uri)
      uri = URI.parse(uri.concat("addresses/search_hostname/#{options[:hostname]}/"))
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      request = Net::HTTP::Get.new(uri.request_uri)
      request.add_field("token",  auth_token)
      response = http.request(request)
      if response.code == "404"
        puts "Requesting IP for #{options[:hostname]}"
      elsif response.code == "200"
        options[:ip] = JSON.parse(response.body)["data"][0]["ip"]
        abort "#{options[:hostname]} is already assigned #{JSON.parse(response.body)["data"][0]["ip"]}"
      else
        abort "There was an error requesting your IP address, IPAM returned code: #{response.code}, message: #{response.body}"
      end

      # Get the id of the VLAN to request address

      uri = options[:add_uri]
      uri = URI.escape(uri)
      uri = URI.parse(uri.concat("subnets/cidr/#{options[:subnet]}"))
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      request = Net::HTTP::Get.new(uri.request_uri)
      request.add_field("token",  auth_token)
      response = http.request(request)
      if response.code =="404"
        abort "The subnet you requested #{options[:subnet]} can't be found, message: #{response.body}"
      elsif response.code != "200"
        abort "There was an error while searching for the id of the requested subnet #{response.code}, message: #{response.body}"
      end
      subnetId = JSON.parse(response.body)["data"][0]["id"]

      # Get the first free address in requested subnet

      uri = options[:add_uri]
      uri = URI.escape(uri)
      uri = URI.parse(uri.concat("subnets/#{subnetId}/first_free/"))
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      request = Net::HTTP::Get.new(uri.request_uri)
      request.add_field("token",  auth_token)
      response = http.request(request)
      if response.code != "200"
        abort "There was an error while requesting first free address code: #{response.code}, message: #{response.body}"
      end
      options[:ip] = JSON.parse(response.body)["data"]

      # Commit the new IP and hostname to the database.

      uri = options[:add_uri]
      uri = URI.escape(uri)
      uri = URI.parse(uri.concat("addresses/?subnetId=#{subnetId}&ip=#{options[:ip]}&hostname=#{options[:hostname]}&owner=#{username}"))
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      request = Net::HTTP::Post.new(uri.request_uri)
      request.add_field("token",  auth_token)
      response = http.request(request)
      if response.code != "201"
        abort "There was an error saving the IP and host to the database, returned code: #{response.code}, message: #{response.body}"
      end
      puts "Assigned IP: #{options[:ip]}"
    end
  end
end
