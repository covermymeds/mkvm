# Plugin to auto request an IP from IPAM

require "net/https"
require "uri"
require "ipaddr"

class Autoip < Plugin

  def self.optparse opts, options
    opts.separator 'automated IPAM options:'
    opts.on( '-s subnet', '--subnet NAME', 'subnet name') do |x|
      options[:subnet] = x
    end
    opts.on( '--auto-uri uri', "URI for auto IP system(#{options[:auto_uri]})") do |x|
      options[:auto_uri] = x
    end
    return opts, options
  end

  def self.pre_validate options
    # if no subnet specified, use the APP_ENV
    options[:subnet] = options[:app_env] if ! options[:subnet]
    if ! options[:ip]
      # Remove any 'DOMAIN\' prefix from the username
      username = options[:username]
      username.gsub(/^.+\\(.*)/, '\1')
      puts "Requesting IP in #{options[:subnet]} vlan"

      # Get an IP from our IPAM system
      uri = "#{options[:auto_uri]}/api/getFreeIP.php?subnet=#{options[:subnet]}&host=#{options[:hostname]}&user=#{username}"
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
