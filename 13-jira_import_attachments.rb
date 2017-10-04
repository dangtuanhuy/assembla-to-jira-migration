# frozen_string_literal: true

load './lib/common.rb'

# TODO
# Move to common.rb -- start

# Assembla users
assembla_users_csv = "#{OUTPUT_DIR_ASSEMBLA}/report-users.csv"
@users_assembla = csv_to_array(assembla_users_csv)

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

# Move to common.rb -- end

restart_offset = 0

# If argv0 is passed use it as restart offset (e.g. earlier ended prematurely)
unless ARGV[0].nil?
  goodbye("Invalid arg='#{ARGV[0]}', must be one a number") unless /^\d+$/.match(ARGV[0])
  restart_offset = ARGV[0].to_i
  puts "Restart at offset: #{restart_offset}"
end

# Jira tickets
tickets_jira_csv = "#{OUTPUT_DIR_JIRA}/jira-tickets.csv"
@tickets_jira = csv_to_array(tickets_jira_csv)

@total_tickets = @tickets_jira.length

goodbye("Invalid arg='#{ARGV[0]}', cannot be greater than the number of tickets=#{@total_tickets}") if restart_offset > @total_tickets

@a_id_to_j_id = {}
@tickets_jira.each do |ticket|
  @a_id_to_j_id[ticket['assembla_ticket_id']] = ticket['jira_ticket_id']
end

# Downloaded attachments
downloaded_attachments_csv = "#{OUTPUT_DIR_JIRA}/jira-attachments-download.csv"
@downloaded_attachments = csv_to_array(downloaded_attachments_csv)
@attachments_total = @downloaded_attachments.length

puts "Total attachments: #{@attachments_total}"

# IMPORTANT: Make sure that the downloads are ordered chronologically from first (oldest) to last (newest)
@downloaded_attachments.sort! { |x, y| x['created_at'] <=> y['created_at'] }

@jira_attachments = []

# created_at,created_by,assembla_attachment_id,assembla_ticket_id,filename,content_type
@downloaded_attachments.each_with_index do |attachment, index|
  assembla_attachment_id = attachment['assembla_attachment_id']
  assembla_ticket_id = attachment['assembla_ticket_id']
  jira_ticket_id = @a_id_to_j_id[attachment['assembla_ticket_id']]
  filename = attachment['filename']
  filepath = "#{OUTPUT_DIR_JIRA_ATTACHMENTS}/#{filename}"
  content_type = attachment['content_type']
  created_at = attachment['created_at']
  created_by = attachment['created_by']
  if created_by && created_by.length.positive?
    created_by.sub!(/@.*$/,'')
    email = @user_login_to_email[created_by]
  else
    created_by = JIRA_API_ADMIN_USER
    email = JIRA_API_ADMIN_EMAIL
  end
  url = "#{URL_JIRA_ISSUES}/#{jira_ticket_id}/attachments"
  counter = index + 1
  next if counter < restart_offset
  percentage = ((counter * 100) / @attachments_total).round.to_s.rjust(3)
  payload = { mulitpart: true, file: File.new(filepath, 'rb') }
  base64_encoded = if JIRA_SERVER_TYPE == 'hosted'
                     Base64.encode64(created_by + ':' + created_by)
                   else
                     Base64.encode64(email + ':' + created_by)
                   end
  headers = { 'Authorization': "Basic #{base64_encoded}", 'X-Atlassian-Token': 'no-check' }
  begin
    response = RestClient::Request.execute(method: :post, url: url, payload: payload, headers: headers)
    puts "#{percentage}% [#{counter}|#{@attachments_total}] POST #{url} '#{filename}' (#{content_type}) => OK"
    result = JSON.parse(response.body)
    jira_attachment_id = result[0]['id']
    @jira_attachments << {
      jira_attachment_id: jira_attachment_id,
      jira_ticket_id: jira_ticket_id,
      assembla_attachment_id: assembla_attachment_id,
      assembla_ticket_id: assembla_ticket_id,
      created_at: created_at,
      filename: filename,
      content_type: content_type
    }
  rescue RestClient::ExceptionWithResponse => e
    rest_client_exception(e, 'POST', url)
  rescue => e
    puts "#{percentage}% [#{counter}|#{@comments_total}] POST #{url} => NOK (#{e.message})"
  end
end

puts "Total all: #{@jira_attachments.length}"
attachments_jira_csv = "#{OUTPUT_DIR_JIRA}/jira-attachments-import.csv"
write_csv_file(attachments_jira_csv, @jira_attachments)
