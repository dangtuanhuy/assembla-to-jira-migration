# frozen_string_literal: true

load './lib/common.rb'

def jira_upload_attachment(issue_id, filepath)
  result = nil?

  url = "#{URL_JIRA_ISSUES}/#{issue_id}/attachments"
  payload = { mulitpart: true, file: File.new(filepath, 'rb') }
  headers = JIRA_HEADERS_ADMIN.merge({ 'X-Atlassian-Token': 'no-check' })

  begin
    response = RestClient::Request.execute(method: :post, url: url, payload: payload, headers: headers)
    result = JSON.parse(response)
    puts "POST #{url} #{filepath} => OK"
  rescue => e
    message = e.message
    puts "POST #{url} #{filepath} => NOK (#{message})"
  end
  result
end

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
issue_id = 'OOPM-2695'
filepath = 'images/Fry.png'
#filepath = 'data/jira/travelcommerce-accelya-cs-atlassian-net-443/attachments/image.2030.png'

results = jira_upload_attachment(issue_id, filepath)
if results
  results = jira_get_issue_fields(issue_id, ['attachment'])
  if results
    attachments = results['fields']['attachment']
    puts "Attachments: #{attachments.length}"
    attachments.each_with_index do |a, idx|
      puts " #{idx + 1} id='#{a['id']}' filename='#{a['filename']}' mimeType='#{a['mimeType']}' content='#{a['content']}' thumbnail='#{a['thumbnail']}'"
    end
  end
end
