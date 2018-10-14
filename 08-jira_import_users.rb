# frozen_string_literal: true

load './lib/common.rb'

# IMPORTANT: Make sure that the `JIRA_API_ADMIN_USER` exists, is activated and belongs to both
# the `site-admins` and the `jira-administrators` groups.
#
@jira_administrators = jira_get_group('jira-administrators')
admin_administrator = @jira_administrators.detect{|user| user['emailAddress'] == JIRA_API_ADMIN_EMAIL}

@jira_site_admins = jira_get_group('site-admins')
admin_site_admin = @jira_site_admins.detect{|user| user['emailAddress'] == JIRA_API_ADMIN_EMAIL}

@jira_core_users = jira_get_group('jira-core-users')

goodbye("Admin user with JIRA_API_ADMIN_EMAIL='#{JIRA_API_ADMIN_EMAIL}' does NOT exist or does NOT belong to both the 'jira-administrators' and the 'site-admins' groups.") unless admin_site_admin && admin_administrator

goodbye("Admin user with JIRA_API_ADMIN_EMAIL='#{JIRA_API_ADMIN_EMAIL}' is NOT active, please activate user.") unless admin_site_admin['active'] && admin_administrator['active']

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
