require 'json'
require 'net/http'
require "pp"

class IPAM
    def initialize(api, app)
        @api = api
        @app = app
    end

    def login!(username, password)
        u = self.uri("#{endpoint}/user/")
        http = Net::HTTP.new(u.host, u.port)
        http.use_ssl = true
        request = Net::HTTP::Post.new(u.request_uri)
        request.basic_auth username, password
        response = http.request(request)
        @token = JSON.parse(response.body, :symbolize_names => true)[:data][:token]
    end

    def ips(hostname)
        response = search_hostname(hostname)
        JSON.parse(response.body, :symbolize_names => true)[:data].map { |d| d[:ip] }
    end

    private

    def endpoint
        "#{@api}/#{@app}"
    end

    def search_hostname(hostname)
        get(uri("#{endpoint}/addresses/search_hostname/#{hostname}/"))
    end

    def get(uri)
        Net::HTTP.start(uri.host, uri.port, :use_ssl => true) do |http|
            request = Net::HTTP::Get.new uri
            request['token'] = @token
            http.request request
        end
    end

    def uri(address)
        URI.parse(URI.escape(address))
    end
end
