# frozen_string_literal: true

load './lib/common.rb'
load './lib/users-assembla.rb'

restart_offset = 0

# If argv0 is passed use it as restart offset (e.g. earlier ended prematurely)
unless ARGV[0].nil?
  goodbye("Invalid arg='#{ARGV[0]}', must be a number") unless /^\d+$/.match?(ARGV[0])
  restart_offset = ARGV[0].to_i
  puts "Restart at offset: #{restart_offset}"
end

# Jira tickets
tickets_jira_csv = "#{OUTPUT_DIR_JIRA}/jira-tickets.csv"
@tickets_jira = csv_to_array(tickets_jira_csv)

@total_tickets = @tickets_jira.length

# TODO: Move this to ./lib/tickets-assembla.rb and reuse in other scripts.
@a_id_to_a_nr = {}
@a_id_to_j_id = {}
@a_id_to_j_key = {}
@tickets_jira.each do |ticket|
  @a_id_to_a_nr[ticket['assembla_ticket_id']] = ticket['assembla_ticket_number']
  @a_id_to_j_id[ticket['assembla_ticket_id']] = ticket['jira_ticket_id']
  @a_id_to_j_key[ticket['assembla_ticket_id']] = ticket['jira_ticket_key']
end

# Downloaded attachments
downloaded_attachments_csv = "#{OUTPUT_DIR_JIRA}/jira-attachments-download.csv"
@downloaded_attachments = csv_to_array(downloaded_attachments_csv)
@attachments_total = @downloaded_attachments.length

puts "Total attachments: #{@attachments_total}"

goodbye("Invalid arg='#{ARGV[0]}', cannot be greater than the number of attachments=#{@attachments_total}") if restart_offset > @attachments_total

# IMPORTANT: Make sure that the downloads are ordered chronologically from first (oldest) to last (newest)
@downloaded_attachments.sort! { |x, y| x['created_at'] <=> y['created_at'] }

@jira_attachments_ok = []
@jira_attachments_nok = []

# created_at,created_by,assembla_attachment_id,assembla_ticket_id,filename,content_type
@downloaded_attachments.each_with_index do |attachment, index|
  assembla_attachment_id = attachment['assembla_attachment_id']
  assembla_ticket_id = attachment['assembla_ticket_id']
  assembla_ticket_nr = @a_id_to_a_nr[assembla_ticket_id]
  jira_ticket_id = @a_id_to_j_id[assembla_ticket_id]
  jira_ticket_key = @a_id_to_j_key[assembla_ticket_id]
  filename = attachment['filename']
  filepath = "#{OUTPUT_DIR_JIRA_ATTACHMENTS}/#{filename}"
  content_type = attachment['content_type']
  created_at = attachment['created_at']
  created_by = attachment['created_by']
  jira_attachment_id = nil
  message = ''
  if created_by && created_by.length.positive?
    created_by.sub!(/@.*$/, '')
    # email = @user_login_to_email[created_by]
  else
    created_by = JIRA_API_ADMIN_USER
    # email = JIRA_API_ADMIN_EMAIL
    # password = ENV['JIRA_API_ADMIN_PASSWORD']
  end
  url = "#{URL_JIRA_ISSUES}/#{jira_ticket_id}/attachments"
  counter = index + 1
  next if counter < restart_offset
  percentage = ((counter * 100) / @attachments_total).round.to_s.rjust(3)
  begin
    payload = { mulitpart: true, file: File.new(filepath, 'rb') }
    base64_encoded = if JIRA_SERVER_TYPE == 'hosted'
                       Base64.encode64(created_by + ':' + created_by)
                     else
                       Base64.encode64(JIRA_API_ADMIN_EMAIL + ':' + ENV['JIRA_API_ADMIN_PASSWORD'])
                     end
    headers = { 'Authorization': "Basic #{base64_encoded}", 'X-Atlassian-Token': 'no-check' }

    response = RestClient::Request.execute(method: :post, url: url, payload: payload, headers: headers)
    puts "#{percentage}% [#{counter}|#{@attachments_total}] POST #{url} '#{filename}' (#{content_type}) => OK"
    result = JSON.parse(response.body)
    jira_attachment_id = result[0]['id']
  rescue RestClient::ExceptionWithResponse => e
    message = rest_client_exception(e, 'POST', url, payload)
  rescue => e
    message = e.message
    puts "#{percentage}% [#{counter}|#{@comments_total}] POST #{url} #{filename} => NOK (#{message})"
  end
  if jira_attachment_id
    @jira_attachments_ok << {
      jira_attachment_id: jira_attachment_id,
      jira_ticket_id: jira_ticket_id,
      jira_ticket_key: jira_ticket_key,
      assembla_attachment_id: assembla_attachment_id,
      assembla_ticket_id: assembla_ticket_id,
      assembla_ticket_nr: assembla_ticket_nr,
      created_at: created_at,
      filename: filename,
      content_type: content_type
    }
  else
    @jira_attachments_nok << {
      jira_ticket_id: jira_ticket_id,
      jira_ticket_key: jira_ticket_key,
      assembla_attachment_id: assembla_attachment_id,
      assembla_ticket_id: assembla_ticket_id,
      assembla_ticket_nr: assembla_ticket_nr,
      created_at: created_at,
      filename: filename,
      content_type: content_type,
      message: message
    }
  end
end

puts "Total ok: #{@jira_attachments_ok.length}"
attachments_ok_jira_csv = "#{OUTPUT_DIR_JIRA}/jira-attachments-import-ok.csv"
write_csv_file(attachments_ok_jira_csv, @jira_attachments_ok)

if @jira_attachments_nok.length.positive?
  puts "Total nok: #{@jira_attachments_nok.length}"
  attachments_nok_jira_csv = "#{OUTPUT_DIR_JIRA}/jira-attachments-import-nok.csv"
  write_csv_file(attachments_nok_jira_csv, @jira_attachments_nok)
end
