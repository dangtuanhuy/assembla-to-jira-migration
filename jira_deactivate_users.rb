# frozen_string_literal: true

load './lib/common.rb'
load './lib/users-jira.rb'

# exit unless confirm('WARNING: You are about to deactivate all users, are you sure?')

@jira_all_users = jira_get_all_users

@groupnames = %w{jira-core-users jira-software-users}

@groupnames.each do |groupname|
  # accountId,displayName,active
  @jira_all_users.each do |user|
    display_name = user['displayName']
    next if @jira_ignore_users.include?(display_name)
    jira_remove_user_from_group(groupname, user)
  end
end
