# frozen_string_literal: true

load './lib/common.rb'

# --- JIRA Tickets --- #
# result,retries,message,jira_ticket_id,jira_ticket_key,project_id,summary,issue_type_id,issue_type_name,
# assignee_name,reporter_name,priority_name,status_name,labels,description,assembla_ticket_id,assembla_ticket_number,
# milestone_name,story_rank
tickets_jira_csv = "#{OUTPUT_DIR_JIRA}/jira-tickets.csv"
@tickets_jira = csv_to_array(tickets_jira_csv).select { |ticket| ticket['result'] == 'OK' }

@names = []
@unknown_users = {}
@tickets_jira.select { |t| t['reporter_name'] =~ /unknown/i }.each do |t|
  name = t['reporter_name']
  key = t['jira_ticket_key']
  unless @unknown_users[name]
    @names << name
    @unknown_users[name] = []
  end
  @unknown_users[name] << key
end

@names.sort_by{|n| n.split('-')[1].to_i}.each do |name|
  keys = @unknown_users[name]
  puts "#{name}: #{keys.length}"
  keys.each do |k|
    puts "* #{k}"
  end
end
