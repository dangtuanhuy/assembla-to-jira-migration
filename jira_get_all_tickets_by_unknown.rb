# frozen_string_literal: true

load './lib/common.rb'

# --- JIRA Tickets --- #
# result,retries,message,jira_ticket_id,jira_ticket_key,project_id,summary,issue_type_id,issue_type_name,
# assignee_name,reporter_name,priority_name,status_name,labels,description,assembla_ticket_id,assembla_ticket_number,
# milestone_name,story_rank
tickets_jira_csv = "#{OUTPUT_DIR_JIRA}/jira-tickets.csv"
@tickets_jira = csv_to_array(tickets_jira_csv).select { |ticket| ticket['result'] == 'OK' }

# --- JIRA comments --- #
# jira_comment_id,jira_ticket_id,jira_ticket_key,assembla_comment_id,assembla_ticket_id,user_login,body
comments_jira_csv = "#{OUTPUT_DIR_JIRA}/jira-comments.csv"
@comments_jira = csv_to_array(comments_jira_csv)

@names = []
@unknown_users = {}
@tickets_jira.select { |t| t['reporter_name'] =~ /unknown/i }.each do |t|
  name = t['reporter_name']
  key = t['jira_ticket_key']
  unless @unknown_users[name]
    @names << name
    @unknown_users[name] = {}
    @unknown_users[name]['description'] = []
  end
  @unknown_users[name]['description'] << key
end

@comments_jira.select { |c| c['user_login'] =~ /unknown/i}.each do |c|
  next unless c['body'].nil? || c['body'].length.zero?
  name = c['user_login']
  id = c['jira_comment_id']
  key = c['jira_ticket_key']
  unless @unknown_users[name]
    @names << name
    @unknown_users[name] = {}
    @unknown_users[name]['comments'] = []
  end
  unless @unknown_users[name]['comments']
    @unknown_users[name]['comments'] = []
  end
  @unknown_users[name]['comments'] << key
end

puts
puts '--- DESCRIPTIONS ---'
puts

@names.sort_by { |n| n.split('-')[1].to_i }.each do |name|
  keys = @unknown_users[name]['description']
  next unless keys
  puts "#{name}: #{keys.length}"
  keys.each do |k|
    puts "* #{k}"
  end
end

#puts
#puts '--- COMMENTS ---'
#puts
#
#@names.sort_by { |n| n.split('-')[1].to_i }.each do |name|
#  keys = @unknown_users[name]['comments']
#  next unless keys
#  puts "#{name}: #{keys.length}"
#  keys.each do |k|
#    puts "* #{k}"
#  end
#end
