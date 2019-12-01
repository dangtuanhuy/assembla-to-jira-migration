# frozen_string_literal: true

load './lib/common.rb'

attachment_id = '12248'

def jira_get_attachment_metadata(id)
  result = nil
  url = "#{JIRA_API_HOST}/attachment/#{id}"
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

results = jira_get_attachment_metadata(attachment_id)
if results
  puts results.inspect
end

