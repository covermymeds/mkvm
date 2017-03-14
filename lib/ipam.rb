require 'json'
require "pp"

require_relative 'http'

class IPAM
  attr_accessor :token
  def initialize(endpoint)
    @endpoint = endpoint
  end

  def login!(username, password)
    begin
      http = Http.new(endpoint)
      response = http.post("user/") do |request|
        request.basic_auth username, password
      end
      result = JSON.parse(response.body, :symbolize_names => true)
      raise result[:message] unless result[:code] == 200
      @token = result[:data][:token]
    rescue Exception => e
      puts "IPAM#login! #{e.message}"
    end
  end

  def ips(hostname)
    begin
      response = search_hostname(hostname)
      search_result = JSON.parse(response.body, :symbolize_names => true)
      raise search_result[:message] unless search_result[:code] == 200
      data = search_result[:data] || []
      data.map { |d| d[:ip] }
    rescue Exception => e
      puts "IPAM#ips #{e.message}"
      raise
    end
  end

  def endpoint
    @endpoint
  end

  def search_hostname(hostname)
    http = Http.new(endpoint)
    http.get("addresses/search_hostname/#{hostname}/") do |request|
      request['token'] = @token
    end
  end

end
