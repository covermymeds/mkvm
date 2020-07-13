#!/usr/bin/env ruby

require "net/https"
require "uri"
require "json"

def okta_asa_delete(team_name, key_id, key_secret, hostname)

  okta_url = "https://app.scaleft.com/v1/teams"

  # Get auth token
  token_uri = URI.parse("#{okta_url}/#{team_name}/service_token")

  header = {"Content-Type": "application/json"}

  http = Net::HTTP.new(token_uri.host, token_uri.port)
  http.use_ssl = true
  request = Net::HTTP::Post.new(token_uri.request_uri, header)
  request.body = {"key_id": key_id,
                  "key_secret": key_secret}.to_json

  response = http.request(request)

  if response.code != '200'
    puts "ERROR: Unable to authenticate to Okta. API Response:"
    puts response.body

    return 1
  else
    bearer_token = JSON.parse(response.body)["bearer_token"]
  end

  # Find the system
  system_uri = URI.parse("#{okta_url}/#{team_name}/servers?hostname=#{hostname}")

  header = {"Authorization": "Bearer #{bearer_token}"}

  http = Net::HTTP.new(system_uri.host, system_uri.port)
  http.use_ssl = true
  request = Net::HTTP::Get.new(system_uri.request_uri, header)

  response = http.request(request)

  if response.code != '200'
    puts "ERROR: Okta ASA API returned an error when attempting to find server '#{hostname}'. API resonse:"
    puts response.body

    return 1
  else
    host_list = JSON.parse(response.body)["list"]

    if host_list.length < 1
      puts "WARN: Unable to find server '#{hostname}' from Okta ASA. API returned empty list..."
      return 0
    end
  end


  # Delete the system
  delete_errors = 0
  host_list.each do |host|
    delete_uri = URI.parse("#{okta_url}/#{team_name}/projects/#{host['project_name']}/servers/#{host['id']}")

    header = {
      "Content-Type": "application/json",
      "Authorization": "Bearer #{bearer_token}",
    }

    http = Net::HTTP.new(delete_uri.host, delete_uri.port)
    http.use_ssl = true
    request = Net::HTTP::Delete.new(delete_uri.request_uri, header)

    response = http.request(request)

    if response.code.start_with?('2')
      puts "SUCCESS: '#{hostname}' deleted successfully"
    else
      puts "ERROR: Unable to delete server '#{hostname}' from Okta ASA. API Response:"
      puts response.body
      
      delete_errors += 1
    end
  end

  return delete_errors
end
