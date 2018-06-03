# frozen_string_literal: true

load './lib/common.rb'

# --- ASSEMBLA Tickets --- #

tickets_assembla_csv = "#{OUTPUT_DIR_ASSEMBLA}/tickets.csv"
comments_assembla_csv = "#{OUTPUT_DIR_ASSEMBLA}/ticket-comments.csv"

@tickets_assembla = csv_to_array(tickets_assembla_csv)
@comments_assembla = csv_to_array(comments_assembla_csv)

@a_id_to_a_nr = {}
@tickets_assembla.each do |ticket|
  @a_id_to_a_nr[ticket['id']] = ticket['number']
end

# --- Filter by date if TICKET_CREATED_ON is defined --- #

tickets_created_on = get_tickets_created_on

if tickets_created_on
  puts "Filter newer than: #{tickets_created_on}"
  tickets_initial = @tickets_assembla.length
  comments_initial = @comments_assembla.length
  @tickets_assembla.select! {|item| item_newer_than?(item, tickets_created_on)}
  @comments_assembla.select! {|item| item_newer_than?(item, tickets_created_on)}
  puts "Tickets: #{tickets_initial} => #{@tickets_assembla.length} ∆#{tickets_initial - @tickets_assembla.length}"
  puts "Comments: #{comments_initial} => #{@comments_assembla.length} ∆#{comments_initial - @comments_assembla.length}"
else
  puts "Tickets: #{@tickets_assembla.length}"
  puts "Comments: #{@comments_assembla.length}"
end

def jira_update_issue_description(issue_key, description, counter, total)
  result = nil
  url = "#{URL_JIRA_ISSUES}/#{issue_key}?notifyUsers=false"
  payload = {
      update: {},
      fields: {
          description: description
      }
  }.to_json
  begin
    RestClient::Request.execute(method: :put, url: url, payload: payload, headers: JIRA_HEADERS_ADMIN)
    percentage = ((counter * 100) / total).round.to_s.rjust(3)
    puts "#{percentage}% [#{counter}|#{total}] PUT #{url} description => OK"
    result = true
  rescue RestClient::ExceptionWithResponse => e
    rest_client_exception(e, 'PUT', url, payload)
  rescue => e
    puts "PUT #{url} description => NOK (#{e.message})"
  end
  result
end

def jira_update_issue_comment_body(issue_key, comment_id, body, counter, total)
  result = nil
  url = "#{URL_JIRA_ISSUES}/#{issue_key}/comment/#{comment_id}"
  payload = {
      body: body
  }.to_json
  begin
    RestClient::Request.execute(method: :put, url: url, payload: payload, headers: JIRA_HEADERS_ADMIN)
    percentage = ((counter * 100) / total).round.to_s.rjust(3)
    puts "#{percentage}% [#{counter}|#{total}] PUT #{url} body => OK"
    result = true
  rescue RestClient::ExceptionWithResponse => e
    rest_client_exception(e, 'PUT', url, payload)
  rescue => e
    puts "PUT #{url} description => NOK (#{e.message})"
  end
  result
end

def markdown_attachment(attachment)
  attachment = attachment[7..-3]
  f = attachment.split('|')
  assembla_attachment_id = f[0]
  id = @attachment_a_id_to_j_id[assembla_attachment_id]
  filename = @attachment_j_id_to_j_filename[id]
  url = URI.escape("#{JIRA_API_BASE}/secure/attachment/#{id}/#{filename}")
  "[#{filename}|#{url}]"
end

def reformat_markdown_attachments(content)
  return content if content.nil? || content.length.zero?
  lines = split_into_lines(content)
  markdown = []
  lines.each do |line|
    if line.strip.length.zero?
      markdown << line
      next
    end
    markdown << line.
        gsub(/\[\[file:(.*?)(\|(.*?))?\]\]/i) { |attachment| markdown_attachment(attachment) }
  end
  markdown.join("\n")
end

# --- JIRA Tickets --- #

tickets_jira_csv = "#{OUTPUT_DIR_JIRA}/jira-tickets.csv"
@tickets_jira = csv_to_array(tickets_jira_csv)
comments_jira_csv = "#{OUTPUT_DIR_JIRA}/jira-comments.csv"
@comments_jira = csv_to_array(comments_jira_csv)
attachments_jira_csv = "#{OUTPUT_DIR_JIRA}/jira-attachments-import-ok.csv"
@attachments_jira = csv_to_array(attachments_jira_csv)

@ticket_a_nr_to_j_key = {}
@tickets_jira.each do |ticket|
  @ticket_a_nr_to_j_key[ticket['assembla_ticket_number']] = ticket['jira_ticket_key']
end

@attachment_a_id_to_j_id = {}
@attachment_j_id_to_j_filename = {}
@attachments_jira.each do |attachment|
  @attachment_a_id_to_j_id[attachment['assembla_attachment_id']] = attachment['jira_attachment_id']
  @attachment_j_id_to_j_filename[attachment['jira_attachment_id']] = attachment['filename']
end

# --- Get ticket descriptions containing attachment links --- #

@tickets_with_links = []
@tickets_assembla.each do |ticket|
  assembla_ticket_number = ticket['number']
  assembla_ticket_description = ticket['description']
  next if assembla_ticket_description.nil? || assembla_ticket_description.length.zero?
  assembla_ticket_description.scan /\[\[file:(.*?)(\|(.*?))?\]\]/i do |match|
    assembla_attachment_id = match[0]
    assembla_attachment_filename = match[1] ? match[1][1..-1] : '(null)'
    jira_issue_key = @ticket_a_nr_to_j_key[assembla_ticket_number]
    jira_attachment_id = @attachment_a_id_to_j_id[assembla_attachment_id]
    jira_attachment_filename = @attachment_j_id_to_j_filename[jira_attachment_id]
    @tickets_with_links << { assembla_ticket_number: assembla_ticket_number, assembla_attachment_id: assembla_attachment_id, assembla_attachment_filename: assembla_attachment_filename, jira_issue_key: jira_issue_key, jira_attachment_id: jira_attachment_id, jira_attachment_filename: jira_attachment_filename } unless jira_issue_key.nil?
  end
end

puts "\nTicket attachments: #{@tickets_with_links.length}"
@tickets_with_links.each do |item|
  assembla_ticket_number = item[:assembla_ticket_number]
  assembla_attachment_id = item[:assembla_attachment_id]
  assembla_attachment_filename = item[:assembla_attachment_filename]
  jira_issue_key = item[:jira_issue_key]
  jira_attachment_id = item[:jira_attachment_id]
  jira_attachment_filename = item[:jira_attachment_filename]
  puts "assembla_ticket_number='#{assembla_ticket_number}', assembla_attachment_id='#{assembla_attachment_id}', assembla_attachment_filename='#{assembla_attachment_filename}', jira_issue_key='#{jira_issue_key}', jira_attachment_id='#{jira_attachment_id}', jira_attachment_filename='#{jira_attachment_filename}'"
end

# --- Get comment bodies containing attachment links --- #

@comments_with_links = []
@comments_jira.each do |comment|
  assembla_comment_id = comment['assembla_comment_id']
  assembla_ticket_id = comment['assembla_ticket_id']
  assembla_ticket_number = @a_id_to_a_nr[assembla_ticket_id]
  jira_comment_id = comment['jira_comment_id']
  jira_issue_key = comment['jira_ticket_key']
  comment_jira_body = comment['body']
  next if comment_jira_body.nil? || comment_jira_body.length.zero?
  comment_jira_body.scan /\[\[file:(.*?)(\|(.*?))?\]\]/i do |match|
    assembla_attachment_id = match[0]
    assembla_attachment_filename = match[1] ? match[1][1..-1] : '(null)'
    jira_attachment_id = @attachment_a_id_to_j_id[assembla_attachment_id]
    jira_attachment_filename = @attachment_j_id_to_j_filename[jira_attachment_id]
    @comments_with_links << { jira_comment_body: comment['body'], assembla_ticket_number: assembla_ticket_number, assembla_comment_id: assembla_comment_id,assembla_attachment_id: assembla_attachment_id, assembla_attachment_filename: assembla_attachment_filename, jira_issue_key: jira_issue_key, jira_comment_id: jira_comment_id, jira_attachment_id: jira_attachment_id, jira_attachment_filename: jira_attachment_filename }
  end
end

puts "\nComment attachments: #{@comments_with_links.length}"
@comments_with_links.each do |item|
  assembla_ticket_number = item[:assembla_ticket_number]
  assembla_comment_id = item[:assembla_comment_id]
  assembla_attachment_id = item[:assembla_attachment_id]
  assembla_attachment_filename = item[:assembla_attachment_filename]
  jira_issue_key = item[:jira_issue_key]
  jira_comment_id = item[:jira_comment_key]
  jira_attachment_id = item[:jira_attachment_id]
  jira_attachment_filename = item[:jira_attachment_filename]
  puts "assembla_ticket_number='#{assembla_ticket_number}', assembla_comment_id='#{assembla_comment_id}', assembla_attachment_id='#{assembla_attachment_id}', assembla_attachment_filename='#{assembla_attachment_filename}', jira_issue_key='#{jira_issue_key}', jira_comment_id='#{jira_comment_id}', jira_attachment_id='#{jira_attachment_id}', jira_attachment_filename='#{jira_attachment_filename}'"
end

total = @tickets_with_links.length
@tickets_with_links.each_with_index do |ticket, index|
  jira_issue_key = ticket[:jira_issue_key]
  issue = jira_get_issue(jira_issue_key)
  fields = issue['fields']
  description_in = fields['description']
  description_out = reformat_markdown_attachments(description_in)
  if description_out != description_in
    jira_update_issue_description(jira_issue_key, description_out, index + 1, total)
  else
    puts "jira_issue_key='#{jira_issue_key}' descriptions are the same => SKIP"
  end
end

total = @comments_with_links.length
@comments_with_links.each_with_index do |comment, index|
  jira_comment_id = comment[:jira_comment_id]
  jira_issue_key = comment[:jira_issue_key]
  comment = jira_get_issue_comment(jira_issue_key, jira_comment_id)
  body_in = comment['body']
  body_out = reformat_markdown_attachments(body_in)
  if body_out != body_in
    jira_update_issue_comment_body(jira_issue_key, jira_comment_id, body_out, index + 1, total)
  else
    puts "jira_issue_key='#{jira_issue_key}', jira_comment_id='#{jira_comment_id}' bodies are the same => SKIP"
  end
end
