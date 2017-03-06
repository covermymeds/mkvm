require 'json'
require 'net/http'
require "pp"

class IPAM
    def initialize(api, app)
        @api = api
        @app = app
    end

    def login!(username, password)
        uri = "#{endpoint}/user/"
        uri = URI.escape(uri)
        uri = URI.parse(uri)
        pp uri
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        request = Net::HTTP::Post.new(uri.request_uri)
        request.basic_auth username, password
        response = http.request(request)
        pp response.body
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
        uri = "#{endpoint}/addresses/search_hostname/#{hostname}/"
        uri = URI.escape(uri)
        uri = URI.parse(uri)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        request = Net::HTTP::Get.new(uri.request_uri)
        request['token'] = @token
        return http.request(request)
    end
end
