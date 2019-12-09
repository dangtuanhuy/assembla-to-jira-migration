# frozen_string_literal: true

load './lib/common.rb'

load './lib/users-jira.rb'

JIRA_API_USER_GROUPS.split(',').each do |group|
  puts "--- #{group} ---"
  jira_get_group(group).each do |user|
    puts "* #{user['name']}"
  end
end
