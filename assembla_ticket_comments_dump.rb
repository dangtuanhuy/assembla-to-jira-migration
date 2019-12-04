# frozen_string_literal: true

load './lib/common.rb'

# --- ASSEMBLA Tickets --- #

# id,number,summary,description,priority,completed_date,component_id,created_on,permission_type,importance,is_story,
# milestone_id,notification_list,space_id,state,status,story_importance,updated_at,working_hours,estimate,
# total_estimate,total_invested_hours,total_working_hours,assigned_to_id,reporter_id,custom_fields,hierarchy_type,
# due_date,assigned_to_name,picture_url
tickets_assembla_csv = "#{OUTPUT_DIR_ASSEMBLA}/tickets.csv"
@tickets_assembla = csv_to_array(tickets_assembla_csv)

# Convert assembla ticket_id to ticket_number
@a_id_to_a_nr = {}
@tickets_assembla.each do |ticket|
  @a_id_to_a_nr[ticket['id']] = ticket['number']
end

# --- Comments from API --- #

# id,comment,user_id,created_on,updated_at,ticket_changes,user_name,user_avatar_url,ticket_id,ticket_number
comments_assembla_csv = "#{OUTPUT_DIR_ASSEMBLA}/ticket-comments.csv"
@comments_assembla = csv_to_array(comments_assembla_csv)

@tickets = {}
@comments_assembla.each do |comment|
  # Skip empty comments
  next if comment['comment'].nil? || comment['comment'].strip.empty?

  ticket_number = comment['ticket_number']
  @tickets[ticket_number] = [] unless @tickets[ticket_number]
  @tickets[ticket_number] << comment
end

# --- Comments from DUMP --- #
#
# id,ticket_id,user_id,created_on,updated_at,comment,ticket_changes,rendered
comments_dump_assembla_csv = "#{OUTPUT_DIR_ASSEMBLA}/ticket-comments-dump.csv"
@comments_dump_assembla = csv_to_array(comments_dump_assembla_csv)

found = []
@comments_dump_assembla.each do |comment|
  # Skip empty comments
  next if comment['comment'].nil? || comment['comment'].strip.empty?

  ticket_id = comment['ticket_id']
  ticket_number = @a_id_to_a_nr[ticket_id]
  comment.delete('ticket_id')
  comment['ticket_number'] = ticket_number
  comment_id = comment['id']
  if ticket_number
    @tickets[ticket_number] = [] unless @tickets[ticket_number]
    unless @tickets[ticket_number].detect { |c| c['id'] == comment_id }
      comment['comment'].gsub!('\\n', "\n")
      @tickets[ticket_number] << comment
      found << { number: ticket_number, id: comment_id}
    end
  else
    puts "Cannot find ticket_number for ticket_id='#{ticket_id}' => SKIP"
  end
end

puts "New comments found: #{found.length}"
found.each do |f|
  puts "ticket_number='#{f[:number]}' comment_id='#{f[:id]}'"
end

@ticket_numbers = []
@tickets.each do |ticket_number, comments|
  @ticket_numbers << ticket_number
  @tickets[ticket_number] = comments.sort_by { |c| c['created_on'] }
end

@ticket_numbers.sort_by { |tn| tn.to_i }

@ticket_numbers.each do |ticket_number|
  puts "ticket_number = #{ticket_number}"
  comments = @tickets[ticket_number]
  comments.each_with_index do |comment, index|
    comment_id = comment['id']
    created_on = comment['created_on']
    puts "- #{index} #{comment_id} #{created_on}"
    comment_comment = if comment['comment'].nil? || comment['comment'].strip.empty?
                        comment['ticket_changes']
                      else
                        comment['comment']
                      end
    puts "-----"
    puts comment_comment
    puts "-----"
  end
end

# id,ticket_id,user_id,created_on,updated_at,comment,ticket_changes,rendered
#comments_dump_assembla_csv = "#{OUTPUT_DIR_ASSEMBLA}/ticket-comments-dump-3.csv"
#@comments_dump_assembla = csv_to_array(comments_dump_assembla_csv)

# --- JIRA Tickets --- #

# result,retries,message,jira_ticket_id,jira_ticket_key,project_id,summary,issue_type_id,issue_type_name,
# assignee_name,reporter_name,priority_name,status_name,labels,description,assembla_ticket_id,assembla_ticket_number,
# milestone_name,story_rank
#tickets_jira_csv = "#{OUTPUT_DIR_JIRA}/jira-tickets.csv"
#@tickets_jira = csv_to_array(tickets_jira_csv).select { |ticket| ticket['result'] == 'OK' }
