# frozen_string_literal: true

load './lib/common.rb'

# Jira tickets
tickets_jira_csv = "#{OUTPUT_DIR_JIRA}/jira-tickets.csv"
@tickets_jira = csv_to_array(tickets_jira_csv).select { |ticket| ticket['result'] == 'OK' }

@a_nr_to_j_id = {}
@tickets_jira.each do |ticket|
  @a_nr_to_j_id[ticket['assembla_ticket_number'].to_i] = ticket['jira_ticket_id']
end

@ticket_nrs = []
# filename = assembla_ticket_number_#{ticket_nr}.pdf
Dir.chdir('/home/kiffin/pdfs')
Dir['*'].sort.each do |filename|
  ticket_nr = filename.match(/\d+/)[0].to_i
  @ticket_nrs << ticket_nr
end

@ticket_nrs.sort!

# Make sure that no pdfs are missing
@tickets_jira.each do |ticket|
  ticket_nr = ticket['assembla_ticket_number'].to_i
  puts "Missing ticket_nr='#{ticket_nr}'" unless @ticket_nrs.include?(ticket_nr)
end

@total_pdfs = @ticket_nrs.length
puts "Total pdfs: #{@total_pdfs}"

@ticket_nrs.each_with_index do |assembla_ticket_nr, index|
  jira_ticket_id = @a_nr_to_j_id[assembla_ticket_nr]
  filename = "assembla_ticket_number_#{assembla_ticket_nr}.pdf"
  content_type = 'application/pdf'
  url = "#{URL_JIRA_ISSUES}/#{jira_ticket_id}/attachments"
  counter = index + 1

  payload = { mulitpart: true, file: File.new(filename, 'rb') }
  headers = JIRA_HEADERS_ADMIN.merge('X-Atlassian-Token': 'no-check')
  percentage = ((counter * 100) / @total_pdfs).round.to_s.rjust(3)

  begin
    RestClient::Request.execute(method: :post, url: url, payload: payload, headers: headers)
    puts "#{percentage}% [#{counter}|#{@total_pdfs}] POST #{url} '#{filename}' (#{content_type}) => OK"
  rescue => e
    message = e.message
    puts "#{percentage}% [#{counter}|#{@comments_total}] POST #{url} #{filename} => NOK (#{message})"
  end
end
