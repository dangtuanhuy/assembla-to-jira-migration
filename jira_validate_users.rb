# frozen_string_literal: true

load './lib/common.rb'

# Assembla: id,login,name,picture,email,organization,phone
users_assembla_csv = "#{OUTPUT_DIR_ASSEMBLA}/users.csv"
@users_assembla = csv_to_array(users_assembla_csv)

# Jira: assemblaId,assemblaLogin,emailAddress,name,key,accountId,displayName,active,accountType
users_jira_csv = "#{OUTPUT_DIR_JIRA}/jira-users.csv"
@users_jira = csv_to_array(users_jira_csv)

fails = 0
@users_jira.each do |j_user|
  unless @users_assembla.detect { |a_user| a_user['id'] = j_user['assemblaid'] }
    fails += 1
    puts "Cannot find id='#{j_user['assemblaid']}'"
  end
end

@users_assembla.each do |a_user|
  unless @users_jira.detect { |j_user| j_user['assemblaid'] = a_user['id'] }
    fails += 1
    puts "Cannot find id='#{a_user['id']}'"
  end
end

puts fails.zero? ? 'PASS' : 'FAIL'

@users_jira.each do |j_user|
  account_id = jira_get_user_account_id(j_user['name'])
  if account_id
    unless @users_jira.detect { |j_u| j_u['accountid'] == account_id }
      puts "Cannot find user with accountid='#{account_id}'"
    end
  else
    fails += 1
    puts "Cannot get accountId for user.name='#{j_user['name']}'"
  end
end

