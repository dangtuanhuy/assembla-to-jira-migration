# frozen_string_literal: true

load './lib/common.rb'
load './lib/users-assembla.rb'

# Jira issue link types and tickets
issuelink_types_jira_csv = "#{OUTPUT_DIR_JIRA}/jira-issuelink-types.csv"
tickets_jira_csv = "#{OUTPUT_DIR_JIRA}/jira-tickets.csv"
@issuelink_types_jira = csv_to_array(issuelink_types_jira_csv)
@tickets_jira = csv_to_array(tickets_jira_csv).select { |ticket| ticket['result'] == 'OK' }

# Filter for ok tickets only
@is_ticket_id = {}
@tickets_jira.each do |ticket|
  @is_ticket_id[ticket['assembla_ticket_id']] = true
end

# Convert assembla_ticket_id to jira_ticket
@assembla_id_to_jira = {}
@jira_id_to_login = {}
@tickets_jira.each do |ticket|
  jira_id = ticket['jira_ticket_id']
  assembla_id = ticket['assembla_ticket_id']
  @assembla_id_to_jira[assembla_id] = jira_id
  @jira_id_to_login[jira_id] = ticket['reporter_name']
end

@tickets_jira = nil

# TEST
tickets_jira_csv_org = "#{OUTPUT_DIR_JIRA}/jira-tickets.csv.org"
@tickets_jira_org = csv_to_array(tickets_jira_csv_org).select { |ticket| ticket['result'] == 'OK' }

@tickets_jira_org.each do |ticket|
  jira_id = ticket['jira_ticket_id']
  assembla_id = ticket['assembla_ticket_id']
  if @assembla_id_to_jira[assembla_id]
    warning("assembla_id='#{assembla_id}' already present")
  else
    @assembla_id_to_jira[assembla_id] = jira_id
  end
  if @jira_id_to_login[jira_id]
    warning("jira_id='#{jira_id}' already present")
  else
    @jira_id_to_login[jira_id] = ticket['reporter_name']
  end
end

@tickets_jira_org = nil
# TEST

# Assembla tickets
# id,ticket1_id,ticket2_id,relationship,created_at,ticket_id,ticket_number,relationship_name
associations_csv = "#{OUTPUT_DIR_ASSEMBLA}/ticket-associations.csv"
@associations_assembla = csv_to_array(associations_csv)

# --- Filter by date if TICKET_CREATED_ON is defined --- #
tickets_created_on = get_tickets_created_on

if tickets_created_on
  puts "Filter newer than: #{tickets_created_on}"
  @associations_assembla.select! { |association| @assembla_id_to_jira[association['ticket1_id']] && @assembla_id_to_jira[association['ticket2_id']] }
end

@total_assembla_associations = @associations_assembla.length
puts "Total Assembla associations: #{@total_assembla_associations}"

# Filter for ok tickets only
@associations_assembla.select! { |c| @is_ticket_id[c['ticket_id']]}

@total_assembla_associations = @associations_assembla.length
puts "Total Assembla associations after: #{@total_assembla_associations}"

# Collect ticket statuses
@relationship_names = {}
@relationship_tickets = {}
@associations_assembla.each do |association|
  ticket_id = association['ticket_id'].to_i
  ticket1_id = association['ticket1_id'].to_i
  ticket2_id = association['ticket2_id'].to_i
  if ticket1_id != ticket_id && ticket2_id != ticket_id
    goodbye("ticket1_id (#{ticket1_id}) != ticket_id (#{ticket_id}) && ticket2_id (#{ticket2_id}) != ticket_id (#{ticket_id})")
  end
  name = association['relationship_name']
  if @relationship_names[name].nil?
    @relationship_names[name] = 0
  else
    @relationship_names[name] += 1
  end
  @relationship_tickets[ticket_id] = { associations: {} } if @relationship_tickets[ticket_id].nil?
  @relationship_tickets[ticket_id][:associations][name] = [] if @relationship_tickets[ticket_id][:associations][name].nil?
  @relationship_tickets[ticket_id][:associations][name] << {
    ticket: ticket1_id == ticket_id ? 2 : 1,
    ticket_id: ticket1_id == ticket_id ? ticket2_id : ticket1_id
  }
end

puts "\nTotal issue link types Jira: #{@issuelink_types_jira.length}"
@issuelink_types_jira.each do |issuelink_type|
  puts "* #{issuelink_type['name']}"
end

puts "\nTotal relationship names Assembla: #{@relationship_names.keys.length}"
@relationship_names.each do |item|
  puts "* #{item[0]}: #{item[1]}"
end

puts "\nTotal tickets: #{@relationship_tickets.keys.length}"

# ---------------------------------------------------------------------------
#
# Assembla associations:
#
# |  #  | Name      | Ticket2           | Ticket1       |
# | --- | --------- | ----------------- | ------------- |
# |  0  | Parent    | is parent of      | is child of   |
# |  1  | Child     | is child of       | is parent of  |
# |  2  | Related   | related to        |               |
# |  3  | Duplicate | is duplication of |               |
# |  4  | Sibling   | is sibling of     |               |
# |  5  | Story     | is story          | is subtask of |
# |  6  | Subtask   | is subtask of     | is story      |
# |  7  | Dependent | depends on        |               |
# |  8  | Block     | blocks            |               |
#
# Jira issue link types:
#
# | Name      | Inward           | Outward    |
# | --------- | ---------------- | ---------- |
# | Blocks    | is blocked by    | blocks     |
# | Cloners   | is cloned by     | clones     |
# | Duplicate | is duplicated by | duplicates |
# | Relates   | relates to       | relates to |
#
# POST /rest/api/2/issueLink
# {
#   type: {
#     name: name
#   },
#   inwardIssue: {
#     id: ticket1_id
#   },
#   outwardIssue: {
#     id: ticket2_id
#   }
# }
#
# ---------------------------------------------------------------------------

# Assembla => Jira mappings:
# 'Related' => 'Relates' (replace 'd' with 's')
# 'Duplicate' => 'Duplicate' (exact match)
# 'Block' => 'Blocks' (append 's')

# POST /rest/api/2/issueLink
def jira_update_association(name, ticket1_id, ticket2_id, ticket_id, counter)
  result = nil
  user_login = @jira_id_to_login[ticket_id]
  user_login.sub!(/@.*$/,'')
  user_email = @user_login_to_email[user_login]
  headers = headers_user_login(user_login, user_email)
  name.capitalize!
  name = 'Relates' if name == 'Related'
  name = 'Blocks' if name == 'Block'
  url = URL_JIRA_ISSUELINKS
  payload = {
    type: {
      name: name
    },
    inwardIssue: {
      id: "#{ticket1_id}"
    },
    outwardIssue: {
      id: "#{ticket2_id}"
    }
  }.to_json
  begin
    percentage = ((counter * 100) / @total_assembla_associations).round.to_s.rjust(3)
    RestClient::Request.execute(method: :post, url: url, payload: payload, headers: headers)
    puts "#{percentage}% [#{counter}|#{@total_assembla_associations}] PUT #{url} '#{name}' => OK"
    result = true
  rescue RestClient::ExceptionWithResponse => e
    rest_client_exception(e, 'PUT', url, payload)
  rescue => e
    puts "#{percentage}% [#{counter}|#{@total_assembla_associations}] PUT #{url} #{payload.inspect} => NOK (#{e.message})"
  end
  result
end

@total_updates = 0
@associations_tickets_jira_csv = "#{OUTPUT_DIR_JIRA}/jira-tickets-associations.csv"

@associations_assembla.each_with_index do |association, index|
  counter = index + 1
  name = association['relationship_name']
  skip = ASSEMBLA_SKIP_ASSOCIATIONS.include?(name.split.first)
  unknown = false
  assembla_ticket1_id = association['ticket1_id']
  assembla_ticket2_id = association['ticket2_id']
  assembla_ticket_id = association['ticket_id']
  jira_ticket1_id = @assembla_id_to_jira[assembla_ticket1_id]
  jira_ticket2_id = @assembla_id_to_jira[assembla_ticket2_id]
  jira_ticket_id = @assembla_id_to_jira[assembla_ticket_id]
  if jira_ticket1_id.to_i.zero?
    puts "Association name=#{name}, assembla_ticket1_id=#{assembla_ticket1_id} => unknown jira_ticket1_id"
    unknown = true
  end
  if jira_ticket2_id.to_i.zero?
    puts "Association name=#{name}, assembla_ticket2_id=#{assembla_ticket2_id} => unknown jira_ticket2_id"
    unknown = true
  end
  unless skip or unknown
    results = jira_update_association(name, jira_ticket1_id, jira_ticket2_id,  jira_ticket_id, counter)
  end
  @total_updates += 1 if results
  result = if skip
             'SKIP'
           elsif unknown
             'UNKNOWN'
           elsif results
             'OK'
           else
             'NOK'
           end
  associations_ticket = {
    result: result,
    assembla_ticket1_id: assembla_ticket1_id,
    jira_ticket1_id: jira_ticket1_id,
    assembla_ticket2_id: assembla_ticket2_id,
    jira_ticket2_id: jira_ticket2_id,
    relationship_name: name.capitalize
  }
  write_csv_file_append(@associations_tickets_jira_csv, [associations_ticket], counter == 1)
end

puts "\nTotal updates: #{@total_updates}"
puts @associations_tickets_jira_csv
