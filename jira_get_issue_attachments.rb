# frozen_string_literal: true

load './lib/common.rb'

def jira_get_issue_fields(issue_id, fields)
  result = nil
  url = "#{URL_JIRA_ISSUES}/#{issue_id}?#{fields.join('&')}"
  #url = "#{URL_JIRA_ISSUES}/#{issue_id}?fields=*all"
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

# DUMMY
#issue_id = 'OOPM-2695'
# Example bad attachments bit
issue_id = 'OOPM-1674'

results = jira_get_issue_fields(issue_id, ['attachment'])
if results
  attachments = results['fields']['attachment']
  puts "Attachments: #{attachments.length}"
  attachments.each_with_index do |a, idx|
    puts " #{idx + 1} id='#{a['id']}' filename='#{a['filename']}' mimeType='#{a['mimeType']}' content='#{a['content']}' thumbnail='#{a['thumbnail']}'"
  end
end
