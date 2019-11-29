# frozen_string_literal: true

load './lib/common.rb'
load './lib/users-assembla.rb'

# Assembla tickets
tickets_csv = "#{OUTPUT_DIR_ASSEMBLA}/tickets.csv"
@tickets_assembla = csv_to_array(tickets_csv)

# --- Filter by date if TICKET_CREATED_ON is defined --- #
tickets_created_on = get_tickets_created_on

if tickets_created_on
  puts "\nFilter newer than: #{tickets_created_on}"
  @tickets_assembla.select! { |item| item_newer_than?(item, tickets_created_on) }
end

@total_assembla_tickets = @tickets_assembla.length
puts "\nTotal Assembla tickets: #{@total_assembla_tickets}"

# Jira tickets
tickets_jira_csv = "#{OUTPUT_DIR_JIRA}/jira-tickets.csv"
@tickets_jira = csv_to_array(tickets_jira_csv).select { |ticket| ticket['result'] == 'OK' }

@is_ticket_id = {}
@tickets_jira.each do |ticket|
  @is_ticket_id[ticket['assembla_ticket_id']] = true
end

@tickets_assembla.select! { |item| @is_ticket_id[item['id']] }
@total_assembla_tickets = @tickets_assembla.length
puts "\nTotal Assembla tickets after: #{@total_assembla_tickets}"


# --- JIRA Tickets --- #

users_jira_csv = "#{OUTPUT_DIR_JIRA}/jira-users.csv"

# @jira_users => assemblaid,assemblalogin,key,accountid,name,emailaddress,displayname,active (downcase)
@jira_users = csv_to_array(users_jira_csv)

@assembla_id_to_jira_name = {}
@jira_name_to_email = {}
@jira_users.each do |user|
  @assembla_id_to_jira_name[user['assemblaid']] = user['name']
  @jira_name_to_email[user['name']] = user['emailaddress']
end

# TODO
# Move to common.rb -- start

@a_id_to_j_id = {}
@a_nr_to_j_key = {}
@tickets_jira.each do |ticket|
  assembla_id = ticket['assembla_ticket_id']
  jira_id = ticket['jira_ticket_id']
  jira_key = ticket['jira_ticket_key']
  @a_id_to_j_id[assembla_id] = jira_id
  @a_nr_to_j_key[assembla_id] = jira_key
end

# Move to common.rb -- end

@watchers_not_found = []

# POST /rest/api/2/issue/{issueIdOrKey}/watchers
def jira_update_watcher(issue_id, watcher, counter)
  result = nil
  watcher_email = @jira_name_to_email[watcher]
  # headers = headers_user_login(watcher, watcher_email)
  headers = JIRA_HEADERS_ADMIN
  url = "#{URL_JIRA_ISSUES}/#{issue_id}/watchers"
  payload = "\"#{watcher}\""
  percentage = ((counter * 100) / @total_assembla_tickets).round.to_s.rjust(3)
  begin
    # For a dry-run, comment out the next line
    RestClient::Request.execute(method: :post, url: url, payload: payload, headers: headers)
    puts "#{percentage}% [#{counter}|#{@total_assembla_tickets}] POST #{url} '#{watcher}' => OK"
    result = true
  rescue RestClient::ExceptionWithResponse => e
    message = rest_client_exception(e, 'POST', url, payload)
    if /404/.match?(message)
      @watchers_not_found << watcher
    end
  rescue => e
    puts "#{percentage}% [#{counter}|#{@total_assembla_tickets}] POST #{url} #{watcher} => NOK (#{e.message})"
  end
  result
end

@total_updates = 0
@watchers_tickets_jira_csv = "#{OUTPUT_DIR_JIRA}/jira-tickets-watchers.csv"

@tickets_assembla.each_with_index do |ticket, index|
  counter = index + 1
  assembla_ticket_id = ticket['id']
  assembla_ticket_nr = ticket['number']
  assembla_ticket_watchers = ticket['notification_list']
  jira_ticket_id = @a_id_to_j_id[assembla_ticket_id]
  unless jira_ticket_id
    warning("Cannot find jira_ticket_id for assembla_ticket_id='#{assembla_ticket_id}'")
    next
  end
  jira_ticket_key = @a_nr_to_j_key[assembla_ticket_nr]
  assembla_ticket_watchers.split(',').each do |user_id|
    not_found = false
    result = nil?
    next unless user_id.length.positive?
    watcher = @assembla_id_to_jira_name[user_id]
    unless watcher
      warning("Unknown watcher for user_id=#{user_id}, assembla_ticket_nr=#{assembla_ticket_nr}, jira_ticket_key=#{jira_ticket_key}")
      next
    end
    if @watchers_not_found.index(watcher)
      not_found = true
      puts "Watcher='#{watcher}' previous (404 Not Found) => SKIP"
    else
      result = jira_update_watcher(jira_ticket_id, watcher, counter)
      @total_updates += 1 if result
    end
    if result
      message = 'OK'
    else
      message = 'NOK'
      message += ' (404 Not Found)' if not_found
    end
    updates_tickets = {
      result: message,
      assembla_ticket_id: assembla_ticket_id,
      assembla_ticket_number: assembla_ticket_nr,
      jira_ticket_id: jira_ticket_id,
      jira_ticket_key: jira_ticket_key,
      assembla_user_id: user_id,
      watcher: watcher
    }
    # For a dry-run comment out the next line
    write_csv_file_append(@watchers_tickets_jira_csv, [updates_tickets], counter == 1)
  end
end

puts "\nTotal updates: #{@total_updates}"
puts @watchers_tickets_jira_csv
