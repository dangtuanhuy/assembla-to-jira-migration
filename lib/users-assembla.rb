# frozen_string_literal: true

# Assembla users which have been exported into the users.csv file.
# id,login,name,picture,email,organization,phone
@users_assembla = []

users_assembla_csv = "#{OUTPUT_DIR_ASSEMBLA}/users.csv"
@users_assembla = csv_to_array(users_assembla_csv)
goodbye('Cannot get users!') unless @users_assembla.length.nonzero?

@user_id_to_login = {}
@user_id_to_email = {}
@user_login_to_email = {}
@list_of_user_logins = {}
@users_assembla.each do |user|
  id = user['id']
  login = user['login'].sub(/@.*$/, '')
  email = user['email']
  if email.nil? || email.empty?
    email = "#{login}@#{JIRA_API_DEFAULT_EMAIL}"
  end
  @user_id_to_login[id] = login
  @user_id_to_email[id] = email
  @user_login_to_email[login] = email
  @list_of_user_logins[login] = true
end
