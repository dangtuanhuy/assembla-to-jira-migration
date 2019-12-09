# frozen_string_literal: true


def jira_get_user_by_username(users_jira, username)
  return users_jira.detect { |user| user['name'] == username }
end

# No longer supported.
# def jira_get_user_by_email(users_jira, emailAddress)
#   puts users_jira.inspect
#   return users_jira.detect { |user| user['emailAddress'].casecmp(emailAddress) == 0 }
# end

def jira_get_group(group_name)
  result = []
  batchsize = 50
  startAt = 0
  processing = true
  while processing
    url = "#{JIRA_API_HOST}/group/member?groupname=#{group_name}&includeInactiveUsers=true&startAt=#{startAt}&maxResults=#{batchsize}"
    begin
      response = RestClient::Request.execute(method: :get, url: url, headers: JIRA_HEADERS_ADMIN)
      body = JSON.parse(response.body)
      users = body['values']
      puts "GET #{url} => OK (#{users.length})"
      users.each do |user|
        user.delete_if { |k, _| k =~ /self|avatarurls|timezone/i }
        result << user
      end
      processing = !body['isLast']
    rescue => e
      puts "GET #{url} => NOK (#{e.message})"
      result = []
      processing = false
    end
    startAt = startAt + batchsize if processing
  end
  # We are not interested in system users
  result.select { |user| !/^addon_/.match(user['name']) }
end

# name,key,accountId,displayName,active,accountType
def jira_get_all_users
  users_jira = []
  JIRA_API_USER_GROUPS.split(',').each do |group|
    jira_get_group(group).each do |user|
      unless users_jira.find { |u| u['name'] == user['name'] }
        users_jira << user
      end
    end
  end
  users_jira
end

@jira_ignore_users = [
  'Chat Notifications',
  'Sketch',
  'Jira App for Chat',
  'Trello',
  'Slack',
  'Jira Service Desk Widget',
  'Jira Cloud for Workplace',
  'Statuspage for Jira'
]
