require 'json'
require "pp"

require_relative 'http'

class IPAM
  def initialize(endpoint)
    @endpoint = endpoint
  end

  def login!(username, password)
    http = Http.new("#{endpoint}/user/")
    response = http.post do |request|
      request.basic_auth username, password
    end
    @token = JSON.parse(response.body, :symbolize_names => true)[:data][:token]
  end

  def ips(hostname)
    response = search_hostname(hostname)
    JSON.parse(response.body, :symbolize_names => true)[:data].map { |d| d[:ip] }
  end

  private

  def endpoint
    @endpoint
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

end
