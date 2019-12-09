# frozen_string_literal: true

load './lib/common.rb'

@customfield_story_points = 'customfield_10017'

def jira_update_story_points(key, story_points)
  payload = {}
  payload[:fields] = {}
  payload[:fields]["#{@customfield_story_points}"] = story_points.to_i
  url = "#{URL_JIRA_ISSUES}/#{key}"
  begin
    RestClient::Request.execute(method: :put, url: url, payload: payload.to_json, headers: JIRA_HEADERS_ADMIN)
    puts "POST #{url} story_points='#{story_points}' => OK"
  rescue RestClient::ExceptionWithResponse => e
    rest_client_exception(e, 'POST', url, payload)
  rescue => e
    puts "POST #{url} story_points='#{story_points}' => NOK (#{e.message})"
  end
end

# --- ASSEMBLA Tickets --- #

# id,number,summary,description,priority,completed_date,component_id,created_on,permission_type,importance,is_story,
# milestone_id,notification_list,space_id,state,status,story_importance,updated_at,working_hours,estimate,
# total_estimate,total_invested_hours,total_working_hours,assigned_to_id,reporter_id,custom_fields,hierarchy_type,
# due_date,assigned_to_name,picture_url
tickets_assembla_csv = "#{OUTPUT_DIR_ASSEMBLA}/tickets.csv"
@tickets_assembla = csv_to_array(tickets_assembla_csv)

@estimates = []
puts "number,estimate,total_estimate,working_hours,total_working_hours,total_invested_hours"
@tickets_assembla.each do |ticket|
  number = ticket['number']
  estimate = ticket['estimate'].to_i
  total_estimate = ticket['total_estimate'].to_i
  working_hours = ticket['working_hours'].to_i
  @estimates << { number: number, estimate: estimate } unless estimate.nil? || estimate.zero?
  total_working_hours = ticket['total_working_hours'].to_i
  total_invested_hours = ticket['total_invested_hours'].to_i
  puts "#{number},#{estimate},#{total_estimate},#{working_hours},#{total_working_hours},#{total_invested_hours}"
end

# --- JIRA Tickets --- #

# result,retries,message,jira_ticket_id,jira_ticket_key,project_id,summary,issue_type_id,issue_type_name,
# assignee_name,reporter_name,priority_name,status_name,labels,description,assembla_ticket_id,assembla_ticket_number,
# milestone_name,story_rank
tickets_jira_csv = "#{OUTPUT_DIR_JIRA}/jira-tickets.csv"
@tickets_jira = csv_to_array(tickets_jira_csv).select { |ticket| ticket['result'] == 'OK' }

@estimates.each do |item|
  number = item[:number]
  estimate = item[:estimate]
  story_points = if estimate < 8
                   1
                 elsif estimate <= 16
                   2
                 elsif estimate <= 40
                   3
                 elsif estimate <= 80
                   5
                 else
                   8
                 end
  found = @tickets_jira.find { |t| t['assembla_ticket_number'] == number }
  if found
    key = found['jira_ticket_key']
    jira_update_story_points(key, story_points)
  else
    puts "Cannot find assembla ticket number='#{number}'"
  end
end
