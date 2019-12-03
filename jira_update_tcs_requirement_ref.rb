# frozen_string_literal: true

load './lib/common.rb'

field_name = 'TCS requirement ref'

def jira_get_issue_labels(key)
  result = nil
  url = "#{URL_JIRA_ISSUES}/#{key}?fields=labels"
  begin
    response = RestClient::Request.execute(method: :get, url: url, headers: JIRA_HEADERS_ADMIN)
    result = JSON.parse(response.body)
    puts "GET #{url} labels => OK"
  rescue RestClient::ExceptionWithResponse => e
    rest_client_exception(e, 'GET', url)
  rescue => e
    puts "GET #{url} labels => NOK (#{e.message})"
  end
  result['fields']['labels']
end

def jira_add_label(key, label)
  labels = jira_get_issue_labels(key)
  labels << label
  payload = {}
  payload[:fields] = {}
  payload[:fields]['labels'] = labels
  url = "#{URL_JIRA_ISSUES}/#{key}"
  begin
    RestClient::Request.execute(method: :put, url: url, payload: payload.to_json, headers: JIRA_HEADERS_ADMIN)
    puts "POST #{url} labels='[#{labels.join(',')}]' => OK"
  rescue RestClient::ExceptionWithResponse => e
    rest_client_exception(e, 'POST', url, payload)
  rescue => e
    puts "POST #{url} labels='[#{labels.join(',')}]' => NOK (#{e.message})"
  end
end

# --- ASSEMBLA Tickets --- #

# id,number,summary,description,priority,completed_date,component_id,created_on,permission_type,importance,is_story,
# milestone_id,notification_list,space_id,state,status,story_importance,updated_at,working_hours,estimate,
# total_estimate,total_invested_hours,total_working_hours,assigned_to_id,reporter_id,custom_fields,hierarchy_type,
# due_date,assigned_to_name,picture_url
tickets_assembla_csv = "#{OUTPUT_DIR_ASSEMBLA}/tickets.csv"
@tickets_assembla = csv_to_array(tickets_assembla_csv)

# --- JIRA Tickets --- #

# result,retries,message,jira_ticket_id,jira_ticket_key,project_id,summary,issue_type_id,issue_type_name,
# assignee_name,reporter_name,priority_name,status_name,labels,description,assembla_ticket_id,assembla_ticket_number,
# milestone_name,story_rank
tickets_jira_csv = "#{OUTPUT_DIR_JIRA}/jira-tickets.csv"
@tickets_jira = csv_to_array(tickets_jira_csv).select { |ticket| ticket['result'] == 'OK' }

@custom_fields = @tickets_assembla.reject { |ticket| ticket['custom_fields'].nil? }
puts "Assembla tickets with custom fields: #{@custom_fields.count}"

values = []
@custom_fields.each do |ticket|
  fields = JSON.parse(ticket['custom_fields'].gsub('=>', ':'))
  field = fields[field_name]
  field.gsub!(' ', '')
  if field != ''
    found = values.find { |v| v == field }
    values << field unless found
  end
end

puts "Values found for '#{field_name}': #{values.count}"
values.sort.each { |v| puts "* #{v}" }

@tickets_assembla.each do |ticket|
  number = ticket['number']
  fields = JSON.parse(ticket['custom_fields'].gsub('=>', ':'))
  field = fields[field_name]
  field.gsub!(' ', '')
  next unless field != ''
  number = ticket['number']
  field = "OO-#{field}"
  found = @tickets_jira.find { |t| t['assembla_ticket_number'] == number }
  if found
    key = found['jira_ticket_key']
    jira_add_label(key, field)
  else
    puts "Cannot find ticket number='#{number}'"
  end
end

