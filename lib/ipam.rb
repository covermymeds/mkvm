require 'json'
require "pp"

require_relative 'http'

class IPAM
  attr_accessor :token
  def initialize(endpoint)
    @endpoint = endpoint
  end

  def login!(username, password)
    http = Http.new(endpoint)
    response = http.post("user/") do |request|
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
    http = Http.new(endpoint)
    http.get("addresses/search_hostname/#{hostname}/")
  end

end
