# frozen_string_literal: true

load './lib/common.rb'

# --- JIRA Tickets --- #

tickets_jira_csv = "#{OUTPUT_DIR_JIRA}/jira-tickets.csv"
ticket_links_jira_csv = "#{OUTPUT_DIR_JIRA}/jira-ticket-links.csv"
@tickets_jira = csv_to_array(tickets_jira_csv)
@ticket_links_jira = csv_to_array(ticket_links_jira_csv)

@tickets = {}
@tickets_jira.each do |ticket|
  @tickets[ticket['assembla_ticket_number']] = ticket['jira_ticket_key']
end

def jira_update_summary_and_descr(issue_id, summary, description)
  result = nil
  url = "#{URL_JIRA_ISSUES}/#{issue_id}"
  fields = {}
  fields[:summary] = summary if summary
  fields[:description] = description if description
  payload = {
    update: {},
    fields: fields
  }.to_json
  changed = summary ? 'summary' : ''
  changed += (summary ? ' and ' : '') + 'description'
  begin
    RestClient::Request.execute(method: :put, url: url, payload: payload, headers: JIRA_HEADERS)
    puts "PUT #{url} #{changed} => OK"
    result = true
  rescue RestClient::ExceptionWithResponse => e
    rest_client_exception(e, 'PUT', url, payload)
  rescue => e
    puts "PUT #{url} #{changed} => NOK (#{e.message})"
  end
  result
end

@ticket_links_jira.each do |ticket|
  jira_ticket_key = ticket['jira_ticket_key']
  issue = jira_get_issue(jira_ticket_key)
  fields = issue['fields']

  summary = nil
  description = nil

  description_in = fields['description'].strip
  summary_in = fields['summary'].strip

  blck = ->(t){ markdown_ticket_link(t, @tickets, true) }

  summary_out = summary_in.gsub(/#(\d+)/, &blck)
  summary = summary_out if summary_in != summary_out

  lines_out = []

  lines_in = description_in.split("\n")
  lines_in.each_with_index do |line_in, index|
    # Ignore first line 'Assembla [...]\n\n'
    lines_out << if index.zero?
                   line_in
                 else
                   line_in.gsub(/#(\d+)/, &blck)
                 end
  end

  description_out = lines_out.join("\n")

  description = description_out if description_in != description_out

  jira_update_summary_and_descr(jira_ticket_key, summary, description) if summary || description
end
