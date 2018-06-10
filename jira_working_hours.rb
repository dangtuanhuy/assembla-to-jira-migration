# frozen_string_literal: true

load './lib/common.rb'

tickets_assembla_csv = "#{OUTPUT_DIR_ASSEMBLA}/tickets.csv"
@tickets_assembla = csv_to_array(tickets_assembla_csv)

# Jira tickets
tickets_jira_csv = "#{OUTPUT_DIR_JIRA}/jira-tickets.csv"
@tickets_jira = csv_to_array(tickets_jira_csv)

# Convert assembla_ticket_id to jira_ticket
@a_id_to_j_key = {}
@tickets_jira.each do |ticket|
  jira_key = ticket['jira_ticket_key']
  assembla_id = ticket['assembla_ticket_id']
  @a_id_to_j_key[assembla_id] = jira_key
end

# --- Filter by date if TICKET_CREATED_ON is defined --- #
tickets_created_on = get_tickets_created_on

if tickets_created_on
  @tickets_assembla.select! { |item| item_newer_than?(item, tickets_created_on) }
end

@zero_assembla = @tickets_assembla.select { |ticket| ticket['total_invested_hours'] == '0.0' && ticket['total_working_hours'] == '0.0' }
@todo_assembla = @tickets_assembla.select {|ticket| ticket['total_invested_hours'] == '0.0' && ticket['total_working_hours'] != '0.0' }
@ongoing_assembla = @tickets_assembla.select {|ticket| ticket['total_invested_hours'] != '0.0' && ticket['total_working_hours'] != '0.0' }
@done_assembla = @tickets_assembla.select {|ticket| ticket['total_invested_hours'] != '0.0' && ticket['total_working_hours'] == '0.0' }

zero = @zero_assembla.length
todo = @todo_assembla.length
ongoing = @ongoing_assembla.length
done = @done_assembla.length
total = @tickets_assembla.length

puts "Zero: #{zero}"
puts "Todo: #{todo}"
puts "Ongoing: #{ongoing}"
puts "Done: #{done}"
puts "Total: #{total} (#{zero + todo + ongoing + done == total ? 'OK' : 'NOK'})"

puts "\nZero: #{@zero_assembla.length}"
@zero_csv = []
@done_assembla.each do |ticket|
  assembla_id = ticket['id']
  jira_key = @a_id_to_j_key[assembla_id]
  @zero_csv << {
      assembla_id: assembla_id,
      jira_key: jira_key
  }
  puts "assembla_id='#{assembla_id}', jira_key='#{jira_key}'"
end

puts "\nTodo: #{@todo_assembla.length}"
@todo_csv = []
@todo_assembla.each do |ticket|
  assembla_id = ticket['id']
  remaining = ticket['total_working_hours']
  jira_key = @a_id_to_j_key[assembla_id]
  @todo_csv << {
      assembla_id: assembla_id,
      remaining: remaining,
      jira_key: jira_key
  }
  puts "assembla_id='#{assembla_id}', remaining='#{remaining}', jira_key='#{jira_key}'"
end

puts "\nOngoing: #{@ongoing_assembla.length}"
@ongoing_csv = []
@ongoing_assembla.each do |ticket|
  assembla_id = ticket['id']
  worked = ticket['total_invested_hours']
  remaining = ticket['total_working_hours']
  jira_key = @a_id_to_j_key[assembla_id]
  @ongoing_csv << {
      assembla_id: assembla_id,
      worked: worked,
      remaining: remaining,
      jira_key: jira_key
  }
  puts "assembla_id='#{assembla_id}', worked='#{worked}', remaining='#{remaining}', jira_key='#{jira_key}'"
end

puts "\nDone: #{@done_assembla.length}"
@done_csv = []
@done_assembla.each do |ticket|
  assembla_id = ticket['id']
  worked = ticket['total_invested_hours']
  jira_key = @a_id_to_j_key[assembla_id]
  @done_csv << {
      assembla_id: assembla_id,
      worked: worked,
      jira_key: jira_key
  }
  puts "assembla_id='#{assembla_id}', worked='#{worked}', jira_key='#{jira_key}'"
end

write_csv_file("#{OUTPUT_DIR_JIRA}/jira-working-zero.csv", @zero_csv)
write_csv_file("#{OUTPUT_DIR_JIRA}/jira-working-todo.csv", @todo_csv)
write_csv_file("#{OUTPUT_DIR_JIRA}/jira-working-ongoing.csv", @ongoing_csv)
write_csv_file("#{OUTPUT_DIR_JIRA}/jira-working-done.csv", @done_csv)
