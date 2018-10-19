# frozen_string_literal: true

load './lib/common.rb'

load './lib/users-jira.rb'

# IMPORTANT: Make sure that the `JIRA_API_ADMIN_USER` exists, is activated and belongs to both
# the `site-admins` and the `jira-administrators` groups.
#
@jira_administrators = jira_get_group('jira-administrators')
admin_administrator = @jira_administrators.detect{|user| user['emailAddress'] == JIRA_API_ADMIN_EMAIL}

@jira_site_admins = jira_get_group('site-admins')
admin_site_admin = @jira_site_admins.detect{|user| user['emailAddress'] == JIRA_API_ADMIN_EMAIL}

goodbye("Admin user with JIRA_API_ADMIN_EMAIL='#{JIRA_API_ADMIN_EMAIL}' does NOT exist or does NOT belong to both the 'jira-administrators' and the 'site-admins' groups.") unless admin_site_admin && admin_administrator

goodbye("Admin user with JIRA_API_ADMIN_EMAIL='#{JIRA_API_ADMIN_EMAIL}' is NOT active, please activate user.") unless admin_site_admin['active'] && admin_administrator['active']

# @user_assembla => count,id,login,name,picture,email,organization,phone,...
users_assembla_csv = "#{OUTPUT_DIR_ASSEMBLA}/report-users.csv"
@users_assembla = csv_to_array(users_assembla_csv)
goodbye('Cannot get users!') unless @users_assembla.length.nonzero?

# name,key,accountId,emailAddress,displayName,active
@existing_users_jira = jira_get_users

@users_jira = []
# assembla => jira
# --------    ----
# id       => assemblaId
# login    => name (optional trailing '@.*$' removed)
# email    => emailAddress
# name     => displayName

@users_assembla.each do |user|
  if user['count'].to_i.zero?
    puts "username='#{username}' zero count => SKIP"
    next
  end
  username = user['login'].sub(/@.*$/, '')
  u1 = jira_get_user_by_username(@existing_users_jira, username)
  if u1
    # User exists so add to list
    puts "username='#{username}' already exists => SKIP"
    @users_jira << { 'assemblaId': user['id'] }.merge(u1)
  else
    # User does not exist so create if possible and add to list
    puts "username='#{username}' not found => CREATE"
    u2 = jira_create_user(user)
    if u2
      @users_jira << { 'assemblaId': user['id'] }.merge(u2)
    end
  end
end

jira_users_csv = "#{OUTPUT_DIR_JIRA}/jira-users.csv"
write_csv_file(jira_users_csv, @users_jira)

# Notify inactive users.
inactive_users = @users_jira.reject { |user| user['active'] }

unless inactive_users.length.zero?
  puts "\nIMPORTANT: The following users MUST to be activated before you continue: #{inactive_users.map { |user| user['name'] }.join(', ')}"
end
