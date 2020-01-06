# frozen_string_literal: true

load './lib/common.rb'

def jira_get_issue_comments(issue_id)
  result = nil
  url = "#{URL_JIRA_ISSUES}/#{issue_id}/comment"
  begin
    response = RestClient::Request.execute(method: :get, url: url, headers: JIRA_HEADERS_ADMIN)
    body = JSON.parse(response.body)
    result = body['comments']
    if result
      puts "GET #{url} => OK (#{result.count})"
    end
  rescue RestClient::ExceptionWithResponse => e
    rest_client_exception(e, 'GET', url)
  rescue => e
    puts "GET #{url} => NOK (#{e.message})"
  end
  result
end

issue_id = 'OOPM-1674'

comments = jira_get_issue_comments(issue_id)
if comments
  puts "Comments: #{comments.length}"
  comments.each_with_index do |c, idx|
    puts "#{idx + 1} id='#{c['id']}' author='#{c['author']['displayName']}' created='#{c['created']}'"
    puts '---body---'
    puts c['body']
    puts '-----'
  end
end
