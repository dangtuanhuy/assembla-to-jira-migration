# frozen_string_literal: true

load './lib/common.rb'

# count,id,login,name,picture,email,organization,phone,...
users_assembla_csv = "#{OUTPUT_DIR_ASSEMBLA}/report-users.csv"
@users_assembla = csv_to_array(users_assembla_csv)

@user_id_to_name = {}
@users_assembla.each do |user|
  @user_id_to_name[user['id']] = user['name']
end

# --- ASSEMBLA Tickets --- #

# id,number,summary,description,priority,completed_date,component_id,created_on,permission_type,importance,is_story,
# milestone_id,notification_list,space_id,state,status,story_importance,updated_at,working_hours,estimate,
# total_estimate,total_invested_hours,total_working_hours,assigned_to_id,reporter_id,custom_fields,hierarchy_type,
# due_date,assigned_to_name,picture_url
tickets_assembla_csv = "#{OUTPUT_DIR_ASSEMBLA}/tickets.csv"
@tickets_assembla = csv_to_array(tickets_assembla_csv)

@ticket_id_to_number = {}
@tickets_assembla.each do |ticket|
  @ticket_id_to_number[ticket['id']] = ticket['number']
end

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
  #next if comment['comment'].nil? || comment['comment'].strip.empty?

  ticket_number = comment['ticket_number']
  @tickets[ticket_number] = [] unless @tickets[ticket_number]
  @tickets[ticket_number] << comment
end

# --- Comments from DUMP --- #
#
# id,ticket_id,user_id,created_on,updated_at,comment,ticket_changes,rendered
comments_dump_assembla_csv = "#{OUTPUT_DIR_ASSEMBLA}/ticket-comments-dump.csv"
@comments_dump_assembla = csv_to_array(comments_dump_assembla_csv)

@found = []
@comments_dump_assembla.each do |comment|
  # Skip empty comments
  next if comment['comment'].nil? || comment['comment'].strip.empty?

  ticket_id = comment['ticket_id']
  ticket_number = @a_id_to_a_nr[ticket_id]
  unless ticket_number
    puts "Cannot find ticket_number for ticket_id='#{ticket_id}'"
    next
  end
  comment['ticket_number'] = ticket_number

  user_id = comment['user_id']
  user_name = @user_id_to_name[user_id]
  unless user_name
    puts "Cannot find user_name for user_id='#{user_id}'"
    next
  end
  comment['user_name'] = user_name

  comment['user_avatar_url'] = ''

  if ticket_number
    @tickets[ticket_number] = [] unless @tickets[ticket_number]
    comment_id = comment['id']
    unless @tickets[ticket_number].detect { |c| c['id'] == comment_id }
      comment['comment'].gsub!('\\n', "\n")
      comment['dump'] = true
      @tickets[ticket_number] << comment
      @found << { number: ticket_number, id: comment_id, comment: comment['comment'] }
    end
  else
    puts "Cannot find ticket_number for ticket_id='#{ticket_id}' => SKIP"
  end
end

puts "New comments found: #{@found.length}"

@ticket_numbers = []
@tickets.each do |ticket_number, comments|
  @ticket_numbers << ticket_number
  @tickets[ticket_number] = comments.sort_by { |c| c['created_on'] }
end

@ticket_numbers.sort_by! { |tn| tn.to_i }

@fixed_comments = []
@ticket_numbers.each do |ticket_number|
  puts "ticket_number = #{ticket_number}"
  comments = @tickets[ticket_number]
  comments.each_with_index do |comment, index|
    comment_id = comment['id']
    created_on = comment['created_on']
    dump = comment['dump']
    puts "- #{index + 1} #{comment_id} #{created_on}#{dump ? ' *' : ''}"
    @fixed_comments << comment
  end
end

puts
puts "Found comments: #{@found.length}"
puts "Total comments: #{@fixed_comments.length}"

# id,comment,user_id,created_on,updated_at,ticket_changes,user_name,user_avatar_url,ticket_id,ticket_number
comments_fixed_assembla_csv = "#{OUTPUT_DIR_ASSEMBLA}/ticket-comments-fixed.csv"
write_csv_file(comments_fixed_assembla_csv, @fixed_comments)

