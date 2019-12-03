# frozen_string_literal: true

#
# This script updates the 'duedate' field of all of the already imported jira issues using the 'due_date' field of
# the associated alrwady exported assembla tickets.
#

load './lib/common.rb'

def jira_update_due_date(key, due_date)
  payload = {
      fields: {
          duedate: due_date
      }
  }.to_json
  url = "#{URL_JIRA_ISSUES}/#{key}"
  begin
    RestClient::Request.execute(method: :put, url: url, payload: payload, headers: JIRA_HEADERS_ADMIN)
    puts "POST #{url} due_date='#{due_date}' => OK"
  rescue RestClient::ExceptionWithResponse => e
    rest_client_exception(e, 'POST', url, payload)
  rescue => e
    puts "POST #{url} due_date='#{due_date}' => NOK (#{e.message})"
  end
end

# --- ASSEMBLA Tickets --- #

# id,number,summary,description,priority,completed_date,component_id,created_on,permission_type,importance,is_story,
# milestone_id,notification_list,space_id,state,status,story_importance,updated_at,working_hours,estimate,
# total_estimate,total_invested_hours,total_working_hours,assigned_to_id,reporter_id,custom_fields,hierarchy_type,
# due_date,assigned_to_name,picture_url
tickets_assembla_csv = "#{OUTPUT_DIR_ASSEMBLA}/tickets.csv"
@tickets_assembla = csv_to_array(tickets_assembla_csv)

@due_dates = @tickets_assembla.reject { |ticket| ticket['due_date'].nil? }
puts "Assembla tickets with due dates: #{@due_dates.count}"

# --- JIRA Tickets --- #

# result,retries,message,jira_ticket_id,jira_ticket_key,project_id,summary,issue_type_id,issue_type_name,
# assignee_name,reporter_name,priority_name,status_name,labels,description,assembla_ticket_id,assembla_ticket_number,
# milestone_name,story_rank
tickets_jira_csv = "#{OUTPUT_DIR_JIRA}/jira-tickets.csv"
@tickets_jira = csv_to_array(tickets_jira_csv).select { |ticket| ticket['result'] == 'OK' }

@due_dates.each do |a_ticket|
  ticket_number = a_ticket['number']
  due_date = a_ticket['due_date']
  found = @tickets_jira.find { |t| t['assembla_ticket_number'] == ticket_number }
  if found
    key = found['jira_ticket_key']
    jira_update_due_date(key, due_date)
  else
    puts "Cannot find a_ticket_number='#{a_ticket_number}'"
  end
end

#Dummy
#jira_update_due_date('OOPM-1412', '2020-01-15')
