# frozen_string_literal: true

load './lib/common.rb'

# --- ASSEMBLA Tickets --- #

# id,start_date,due_date,budget,title,user_id,created_at,created_by,space_id,description,is_completed,completed_date,
# updated_at,updated_by,release_level,release_notes,planner_type,pretty_release_level
milestones_assembla_csv = "#{OUTPUT_DIR_ASSEMBLA}/milestones-all.csv"
@milestones_assembla = csv_to_array(milestones_assembla_csv)

@mid_a_to_mname_a = {}
@mname_a_to_mid_a = {}
@milestones_assembla.each do |milestone|
  @mid_a_to_mname_a[milestone['id']] = milestone['title']
  @mname_a_to_mid_a[milestone['title']] = milestone['id']
end

# id,number,summary,description,priority,completed_date,component_id,created_on,permission_type,importance,is_story,
# milestone_id,notification_list,space_id,state,status,story_importance,updated_at,working_hours,estimate,
# total_estimate,total_invested_hours,total_working_hours,assigned_to_id,reporter_id,custom_fields,hierarchy_type,
# due_date,assigned_to_name,picture_url
tickets_assembla_csv = "#{OUTPUT_DIR_ASSEMBLA}/tickets.csv"
@tickets_assembla = csv_to_array(tickets_assembla_csv)

milestone_id = @mname_a_to_mid_a['Sprint#70/R3.3']

@tickets_assembla.each do |ticket|
  next unless ticket['milestone_id'] == milestone_id
  puts ticket['number']
end

# --- JIRA Tickets --- #

# result,retries,message,jira_ticket_id,jira_ticket_key,project_id,summary,issue_type_id,issue_type_name,
# assignee_name,reporter_name,priority_name,status_name,labels,description,assembla_ticket_id,assembla_ticket_number,
# milestone_name,story_rank
tickets_jira_csv = "#{OUTPUT_DIR_JIRA}/jira-tickets.csv"
@tickets_jira = csv_to_array(tickets_jira_csv).select { |ticket| ticket['result'] == 'OK' }

@tickets_jira.each do |ticket|
  next unless ticket['milestone_name'] == 'Sprint#70/R3.3'
  puts ticket['jira_ticket_key']
end
