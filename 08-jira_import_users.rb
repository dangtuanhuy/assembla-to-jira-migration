# frozen_string_literal: true

load './lib/common.rb'

# IMPORTANT: Make sure that the `JIRA_API_ADMIN_USER` exists, is activated and belongs to both
# the `site-admins` and the `jira-administrators` groups.

# admin = jira_get_user(JIRA_API_ADMIN_USER, true)
# goodbye("JIRA_API_ADMIN_USER='#{JIRA_API_ADMIN_USER}' does NOT exist. Please create.") unless admin
# goodbye("JIRA_API_ADMIN_USER='#{JIRA_API_ADMIN_USER}' is NOT active. Please activate.") unless admin['active']
# puts "\nFound JIRA_API_ADMIN_USER='#{JIRA_API_ADMIN_USER}'"
#
# groups = JIRA_SERVER_TYPE == 'hosted' ? %w(jira-administrators) : %w(jira-administrators site-admins)
# groups.each do |group|
#   next if admin['groups']['items'].detect { |item| item['name'] == group}
#   goodbye("Admin user MUST belong to the following groups: [#{groups.join(',')}]. Please add user '#{admin['name']}' to these groups.")
# end

@jira_users = []

users_csv = "#{OUTPUT_DIR_ASSEMBLA}/users.csv"
jira_users_csv = "#{OUTPUT_DIR_JIRA}/jira-users.csv"

users = csv_to_array(users_csv)

users.each do |user|
  count = user['count']
  username = user['login']
  username.sub!(/@.*$/, '')
  next if count == '0'
  u1 = jira_get_user(username, false)
  if u1
    # User exists so add to list
    @jira_users << u1
  else
    # User does not exist so create if possible and add to list
    u2 = jira_create_user(user)
    @jira_users << u2 if u2
  end
end

write_csv_file(jira_users_csv, @jira_users)

inactive_users = @jira_users.reject { |user| user['active'] }

unless inactive_users.length.zero?
  puts "\nIMPORTANT: The following users MUST to be activated before you continue: #{inactive_users.map { |user| user['name'] }.join(', ')}"
end
