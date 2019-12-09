# frozen_string_literal: true

load './lib/common.rb'

load './lib/users-jira.rb'

ACTIVATE = false

# PUT /rest/api/2/user/properties/{propertyKey}
# /rest/usermanagement/1/user?username=andy
def jira_activate_user(user, active)
  username = user['name']
  if user['active'] == active
    puts "username='#{username} active='#{active}' => SKIP"
    return
  end
  url = "#{JIRA_API_BASE}/usermanagement/1/user/#{active ? 'activate' : 'deactivate'}?username=#{username}"
  payload = {
    name: user['name'],
    active: active
  }.to_json
  begin
    RestClient::Request.execute(method: :post, url: url, payload: payload, headers: JIRA_HEADERS_ADMIN)
    puts "POST #{url} active='#{active}', username='#{user['name']}' => OK"
  rescue => e
    puts "POST #{url} active='#{active}', username='#{user['name']}' => NOK (#{e})"
  end
end

@jira_administrators = jira_get_group('jira-administrators')

# name,key,accountId,emailAddress,displayName,active
jira_get_all_users.each do |user|
  next if user['emailAddress'] == JIRA_API_ADMIN_EMAIL
  jira_activate_user(user, ACTIVATE)
end
