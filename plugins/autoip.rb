# Plugin to auto request an IP from IPAM

require "net/https"
require "uri"

class Autoip < Plugin

  def self.optparse opts, options
    opts.separator 'automated IPAM options:'
    opts.on( '-s subnet', '--subnet NAME', 'subnet name') do |x|
      options['subnet'] = x
    end
    opts.on( '--auto-uri uri', "URI for auto IP system(#{options['auto_uri']})") do |x|
      options['auto_uri'] = x
    end
    return opts, options
  end

  def self.pre_validate options
    if ! options[:subnet]
      subnet = options[:app_env]
      if ! options[:ip]

      # Get an IP from our IPAM system
      uri = URI.parse("#{options['auto_uri']}/api/getFreeIP.php?subnet=#{options['subnet']}&host=#{options['hostname']}&user=#{options['username']}")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      request = Net::HTTP::Get.new(uri.request_uri)
      response = http.request(request)
      options[:ip] = response.body
      puts "System will be built with #{options['ip']}"
      return options[:ip]
      end
    end
  end
end
