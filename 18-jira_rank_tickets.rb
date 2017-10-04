# frozen_string_literal: true

load './lib/common.rb'

if JIRA_SERVER_TYPE == 'hosted'
  puts 'No need to run this script for a hosted server.'
  exit
end

# Jira tickets

# result,retries,message,jira_ticket_id,jira_ticket_key,project_id,summary,issue_type_id,issue_type_name,
# assignee_name,reporter_name,priority_name,status_name,labels,description,assembla_ticket_id,assembla_ticket_number,
# theme_name,milestone_name,story_rank
tickets_jira_csv = "#{OUTPUT_DIR_JIRA}/jira-tickets.csv"
@tickets_jira = csv_to_array(tickets_jira_csv)

@tickets_jira_by_rank = @tickets_jira.sort { |x, y| x['story_rank'].to_i <=> y['story_rank'].to_i }

@tickets_jira_by_rank.each do |ticket|
  puts "#{ticket['story_rank']} #{ticket['jira_ticket_key']}"
end

# puts "Sorry, but this has not yet implemented. Please be patient...\n\nFor now you must rank issues manually in Jira."
