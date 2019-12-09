# frozen_string_literal: true

load './lib/common.rb'

load './lib/users-jira.rb'

# name,key,accountId,emailAddress,displayName,active
jira_get_all_users.each do |user|
  puts user.inspect
end
