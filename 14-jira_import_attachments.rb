# frozen_string_literal: true

load './lib/common.rb'

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

# TODO: Move this to ./lib/tickets-assembla.rb and reuse in other scripts.
@a_id_to_a_nr = {}
@a_id_to_j_id = {}
@a_id_to_j_key = {}
@tickets_jira.each do |ticket|
  @a_id_to_a_nr[ticket['assembla_ticket_id']] = ticket['assembla_ticket_number']
  @a_id_to_j_id[ticket['assembla_ticket_id']] = ticket['jira_ticket_id']
  @a_id_to_j_key[ticket['assembla_ticket_id']] = ticket['jira_ticket_key']
end

@tickets_jira = nil

# Downloaded attachments
downloaded_attachments_csv = "#{OUTPUT_DIR_JIRA}/jira-attachments-download.csv"
@downloaded_attachments = csv_to_array(downloaded_attachments_csv)
@total_attachments = @downloaded_attachments.length

puts "Total attachments: #{@total_attachments}"

goodbye("Invalid arg='#{ARGV[0]}', cannot be greater than the number of attachments=#{@total_attachments}") if restart_offset > @total_attachments

# IMPORTANT: Make sure that the downloads are ordered chronologically from first (oldest) to last (newest)
@downloaded_attachments.sort! {|x, y| x['created_at'] <=> y['created_at']}

# Two csv output files will be generated: ok and nok.
@attachments_ok_jira_csv = "#{OUTPUT_DIR_JIRA}/jira-attachments-import-ok.csv"
@attachments_nok_jira_csv = "#{OUTPUT_DIR_JIRA}/jira-attachments-import-nok.csv"

@total_attachments_ok = 0
@total_attachments_nok = 0

# created_at,created_by,assembla_attachment_id,assembla_ticket_id,filename,content_type
@downloaded_attachments.each_with_index do |attachment, index|
  assembla_attachment_id = attachment['assembla_attachment_id']
  assembla_ticket_id = attachment['assembla_ticket_id']
  assembla_ticket_nr = @a_id_to_a_nr[assembla_ticket_id]
  warning("Cannot find assembla_ticket_nr for assembla_ticket_id='#{assembla_ticket_id}'") if assembla_ticket_nr.nil?
  jira_ticket_id = @a_id_to_j_id[assembla_ticket_id]
  warning("Cannot find jira_ticket_id for assembla_ticket_id='#{assembla_ticket_id}'") if jira_ticket_id.nil?
  jira_ticket_key = @a_id_to_j_key[assembla_ticket_id]
  warning("Cannot find jira_ticket_key for assembla_ticket_id='#{assembla_ticket_id}'") if jira_ticket_key.nil? && !jira_ticket_id.nil?
  filename = attachment['filename']
  filepath = "#{OUTPUT_DIR_JIRA_ATTACHMENTS}/#{filename}"
  content_type = attachment['content_type']
  created_at = attachment['created_at']
  created_by = attachment['created_by']
  jira_attachment_id = nil
  message = ''
  if created_by && created_by.length.positive?
    created_by.sub!(/@.*$/, '')
  else
    created_by = JIRA_API_ADMIN_USER
    # email = JIRA_API_ADMIN_EMAIL
    # password = ENV['JIRA_API_ADMIN_PASSWORD']
  end
  url = "#{URL_JIRA_ISSUES}/#{jira_ticket_id}/attachments"
  counter = index + 1
  next if counter < restart_offset
  percentage = ((counter * 100) / @total_attachments).round.to_s.rjust(3)
  begin
    payload = {mulitpart: true, file: File.new(filepath, 'rb')}
    base64_encoded = if JIRA_SERVER_TYPE == 'hosted'
                       Base64.encode64(created_by + ':' + created_by)
                     else
                       Base64.encode64(JIRA_API_ADMIN_EMAIL + ':' + ENV['JIRA_API_ADMIN_PASSWORD'])
                     end
    headers = {'Authorization': "Basic #{base64_encoded}", 'X-Atlassian-Token': 'no-check'}

    response = RestClient::Request.execute(method: :post, url: url, payload: payload, headers: headers)
    result = JSON.parse(response.body)
    jira_attachment_id = result[0]['id']
    # Dry run: uncomment the following line and comment out the previous three lines.
    # jira_attachment_id = counter.even? ? counter : nil
    puts "#{percentage}% [#{counter}|#{@total_attachments}] POST #{url} '#{filename}' (#{content_type}) => OK"
  rescue RestClient::ExceptionWithResponse => e
    message = rest_client_exception(e, 'POST', url, payload)
  rescue => e
    message = e.message
    puts "#{percentage}% [#{counter}|#{@comments_total}] POST #{url} #{filename} => NOK (#{message})"
  end
  if jira_attachment_id
    attachment_ok = {
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
    write_csv_file_append(@attachments_ok_jira_csv, [attachment_ok], @total_attachments_ok.zero?)
    @total_attachments_ok += 1
  else
    attachment_nok = {
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
    write_csv_file_append(@attachments_nok_jira_csv, [attachment_nok], @total_attachments_nok.zero?)
    @total_attachments_nok += 1
  end
end

puts "\nTotal attachments: #{@total_attachments}"

puts "\nTotal OK #{@total_attachments_ok}"
puts @attachments_ok_jira_csv

puts "Total NOK: #{@total_attachments_nok}"
puts @attachments_nok_jira_csv
