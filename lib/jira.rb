require 'pp'

require_relative 'http'

class Jira
  def initialize(endpoint)
    @endpoint = endpoint
    @http = Http.new(@endpoint)
  end

  def login!(username, password)
    @username = username
    @password = password
  end

  def create_issue(body)
    response = @http.post('issue/') do |request|
      request.body = body.to_json
      request.content_type = 'application/json'
      request.basic_auth @username, @password
    end
    response
  end

  def open_firewall_request(project, ips, issue_type="Service Request")
    self.create_issue({
        :fields => {
          :project     => { :key  => project },
          :summary     => "RMVM: decommission IP #{ips.join(', ')}",
          :description => "RMVM is deleting this host.\nDelete this host from firewalls",
          :issuetype   => { :name => issue_type }
        }
      })
  end
end
