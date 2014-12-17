# Plugin to auto request an IP from IPAM

require "net/https"
require "uri"

class Autoip < Plugin

  def self.defaults
    return { :auto_uri => 'https://ipam.dev/'}
  end

  def self.optparse opts, options
    opts.separator ''
    opts.separator 'automated IPAM options:'
    opts.on( '-s subnet', '--subnet NAME', 'subnet name') do |x|
      options['subnet'] = x
    end
    opts.on( '--auto-uri uri', "URI for auto IP system(#{options['auto_uri']})") do |x|
      options['auto_uri'] = x
    end
    return opts, options

  def autoip
    puts "Requesting IP address in #{options['subnet']} subnet."

    # Get an IP from our IPAM system
    uri = URI.parse("#{options['auto_uri']}/api/getFreeIP.php?subnet=#{options['subnet']}&host=#{hostname}&user=#{options['username']}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    request = Net::HTTP::Get.new(uri.request_uri)
    response = http.request(request)
    ip = response.body
    puts "System will be built with #{ip}"
  end
  end
end
