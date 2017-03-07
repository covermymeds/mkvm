require 'net/http'

class Http
  def initialize(address)
    @url = URI.parse(URI.escape(address))
  end

  def endpoint
    http = Net::HTTP.new(@url.host, @url.port)
    http.use_ssl = true
    http
  end

  def post(path)
    request = Net::HTTP::Post.new(URI.join(@url, path))
    yield request if block_given?
    endpoint.request(request)
  end


  def uri(address)
  end
end
