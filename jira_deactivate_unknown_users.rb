# frozen_string_literal: true

load './lib/common.rb'
load './lib/users-jira.rb'

# exit unless confirm('WARNING: You are about to deactivate all users, are you sure?')

@jira_all_users = jira_get_all_users.select { |user| user['name'].match(/unknown/i) }

@groupnames = %w{jira-core-users jira-software-users}
JIRA_API_USER_GROUPS.split(',').each do |group|

# accountId,displayName,active
@jira_all_users.each do |user|
  JIRA_API_.each do |groupname|
end
    jira_remove_user_from_group(groupname, user)
  end
end
