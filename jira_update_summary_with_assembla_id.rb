# frozen_string_literal: true

load './lib/common.rb'

# --- JIRA Tickets --- #

tickets_jira_csv = "#{OUTPUT_DIR_JIRA}/jira-tickets.csv"
@tickets_jira = csv_to_array(tickets_jira_csv).select { |ticket| ticket['result'] == 'OK' }

def jira_update_summary(issue_id, summary)
  result = nil
  url = "#{URL_JIRA_ISSUES}/#{issue_id}?notifyUsers=false"
  fields = {}
  fields[:summary] = summary
  payload = {
      update: {},
      fields: fields
  }.to_json
  begin
    RestClient::Request.execute(method: :put, url: url, payload: payload, headers: JIRA_HEADERS_ADMIN)
    puts "PUT #{url} summary => OK"
    result = true
  rescue RestClient::ExceptionWithResponse => e
    rest_client_exception(e, 'PUT', url, payload)
  rescue => e
    puts "PUT #{url} summary => NOK (#{e.message})"
  end
  result
end

@tickets_jira.each do |ticket|
  jira_ticket_key = ticket['jira_ticket_key']
  summary = ticket['summary']
  ticket_number = ticket['assembla_ticket_number']

  summary = "##{ticket_number} #{summary}"

  jira_update_summary(jira_ticket_key, summary)
end
