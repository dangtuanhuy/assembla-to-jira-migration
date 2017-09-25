# frozen_string_literal: true

load './lib/common.rb'

# Jira tickets
tickets_jira_csv = "#{OUTPUT_DIR_JIRA}/jira-tickets.csv"
@tickets_jira = csv_to_array(tickets_jira_csv)

@assembla_id_to_jira = {}
@tickets_jira.each do |ticket|
  @assembla_id_to_jira[ticket['assembla_ticket_id']] = ticket['jira_ticket_id']
end

# Downloaded attachments
downloaded_attachments_csv = "#{OUTPUT_DIR_JIRA}/jira-attachments-download.csv"
@downloaded_attachments = csv_to_array(downloaded_attachments_csv)
@attachments_total = @downloaded_attachments.length

puts "Total attachments: #{@attachments_total}"

# IMPORTANT: Make sure that the downloads are ordered chronologically from first (oldest) to last (newest)
@downloaded_attachments.sort! { |x, y| x['created_at'] <=> y['created_at'] }

@jira_attachments = []

# created_at,assembla_attachment_id,assembla_ticket_id,filename,content_type
@downloaded_attachments.each_with_index do |attachment, index|
  assembla_attachment_id = attachment['assembla_attachment_id']
  assembla_ticket_id = attachment['assembla_ticket_id']
  jira_ticket_id = @assembla_id_to_jira[attachment['assembla_ticket_id']]
  filename = attachment['filename']
  filepath = "#{OUTPUT_DIR_JIRA_ATTACHMENTS}/#{filename}"
  content_type = attachment['content_type']
  created_at = attachment['created_at']
  created_by = attachment['created_by']
  url = "#{URL_JIRA_ISSUES}/#{jira_ticket_id}/attachments"
  counter = index + 1
  percentage = ((counter * 100) / @attachments_total).round.to_s.rjust(3)
  puts "#{percentage}% [#{counter}|#{@attachments_total}] POST #{url} '#{filename}' (#{content_type}) => OK"
  payload = { mulitpart: true, file: File.new(filepath, 'rb') }
  headers = { 'Authorization': "Basic #{Base64.encode64(created_by + ':' + created_by)}", 'X-Atlassian-Token': 'no-check' }
  begin
    response = RestClient::Request.execute(method: :post, url: url, payload: payload, headers: headers)
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
  end
end

puts "Total all: #{@jira_attachments.length}"
attachments_jira_csv = "#{OUTPUT_DIR_JIRA}/jira-attachments-import.csv"
write_csv_file(attachments_jira_csv, @jira_attachments)
