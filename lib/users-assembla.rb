# frozen_string_literal: true

users_assembla_csv = "#{OUTPUT_DIR_ASSEMBLA}/report-users.csv"
@users_assembla = csv_to_array(users_assembla_csv)

@user_id_to_login = {}
@user_id_to_email = {}
@user_login_to_email = {}
@list_of_logins = {}
@users_assembla.each do |user|
  id = user['id']
  login = user['login'].sub(/@.*$/,'')
  email = user['email']
  if email.nil? || email.empty?
    email = "#{login}@example.org"
  end
  @user_id_to_login[id] = login
  @user_id_to_email[id] = email
  @user_login_to_email[login] = email
  @list_of_logins[login] = true
end
