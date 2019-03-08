# frozen_string_literal: true

load './lib/common.rb'

load './lib/users-jira.rb'

def jira_delete_user(user)
  url = "#{JIRA_API_HOST}/user?accountId=#{user['accountId']}"
  begin
    RestClient::Request.execute(method: :delete, url: url, headers: JIRA_HEADERS_ADMIN)
    puts "DELETE #{url} username='#{user['name']}' => OK"
  rescue => e
    puts "DELETE #{url} username='#{user['name']}' => NOK (#{e})"
  end
end

@jira_administrators = jira_get_group('jira-administrators')

# name,key,accountId,emailAddress,displayName,active
jira_get_users.each do |user|
  next if user['emailAddress'] == JIRA_API_ADMIN_EMAIL
  jira_delete_user(user)
end
