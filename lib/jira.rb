require 'pp'
require 'json'

require_relative 'http'

class Jira
  def initialize(endpoint)
    @endpoint = "#{endpoint}/rest/api/2/"
    @http = Http.new(@endpoint)
  end

  def login!(username, password)
    @username = username
    @password = password
    nil
  end

  def create_issue(body)
    begin
      response = @http.post('issue/') do |request|
        request.body = body.to_json
        request.content_type = 'application/json'
        request.basic_auth @username, @password
      end
      raise "#{response.code}: #{response.message} - #{response.body}" unless response.code == '201'
      response_body = JSON.parse(response.body, :symbolize_names => true)
      response_body
    rescue Exception => e
      puts "Jira#create_issue #{e.message}"
      puts e.backtrace
      raise
    end
  end

  def open_firewall_request(project, ips, issue_type="Service Request")
    puts "Jira#open_firewall_request - #{project} #{ips} #{issue_type}"
    self.create_issue({
        :fields => {
          :project     => { :key  => project },
          :summary     => "RMVM: decommission IP #{ips.join(', ')}",
          :description => "RMVM is deleting this host.\nDelete this host from firewalls",
          :issuetype   => { :name => issue_type }
        }
      })
  end

  # Returns a list of issue types known to the Jira instance.
  # This is only used in the REPL for debugging.
  def list_issue_types
    response = @http.get('issuetype/') do |request|
      request.basic_auth @username, @password
    end
    raise "#{response.code}: #{response.message} - #{response.body}" unless response.code == '200'
    response_body = JSON.parse(response.body, :symbolize_names => true)
    response_body
  end
end
