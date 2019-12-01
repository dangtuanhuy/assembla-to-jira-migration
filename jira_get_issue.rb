# frozen_string_literal: true

load './lib/common.rb'

issue_id = 'TRAVELCOMM-431'
fields = %w{summary description}

def jira_get_issue_fields(issue_id, fields)
  result = nil
  url = "#{URL_JIRA_ISSUES}/#{issue_id}?#{fields.join('&')}"
  begin
    response = RestClient::Request.execute(method: :get, url: url, headers: JIRA_HEADERS_ADMIN)
    result = JSON.parse(response.body)
    if result
      result.delete_if { |k, _| k =~ /self|expand/i }
      puts "GET #{url} => OK"
    end
  rescue RestClient::ExceptionWithResponse => e
    rest_client_exception(e, 'GET', url)
  rescue => e
    puts "GET #{url} => NOK (#{e.message})"
  end
  result
end

results = jira_get_issue_fields(issue_id, fields)
if results
  fields.each do |field|
    puts "--- #{field} ---"
    puts results['fields'][field]
    puts "------"
  end
end

