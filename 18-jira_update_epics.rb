# frozen_string_literal: true

### EXPERIMENTAL

load './lib/common.rb'

puts 'This is still in the EXPERIMENTAL phase.'

# Assembla tickets

# tickets.csv: id,number,summary,description,priority,completed_date,component_id,created_on,permission_type,importance,is_story,milestone_id,notification_list,space_id,state,status,story_importance,updated_at,working_hours,estimate,total_estimate,total_invested_hours,total_working_hours,assigned_to_id,reporter_id,custom_fields,hierarchy_type,due_date,assigned_to_name,picture_url
tickets_assembla_csv = "#{OUTPUT_DIR_ASSEMBLA}/tickets.csv"
@tickets_assembla = csv_to_array(tickets_assembla_csv)

# --- Filter by date if TICKET_CREATED_ON is defined --- #
tickets_created_on = get_tickets_created_on

if tickets_created_on
  puts "Filter newer than: #{tickets_created_on}"
  tickets_initial = @tickets_assembla.length
  @tickets_assembla.select! { |item| item_newer_than?(item, tickets_created_on) }
  puts "Tickets: #{tickets_initial} => #{@tickets_assembla.length} ∆#{tickets_initial - @tickets_assembla.length}"
else
  puts "\nTotal Assembla tickets: #{@tickets_assembla.length}"
end

# hierarchy_type = 3 => epic
@tickets_assembla_epic_h = @tickets_assembla.select { |item| item['hierarchy_type'].to_i == 3 }
@tickets_assembla_epic_s = @tickets_assembla.select { |item| item['summary'] =~ /^epic/i && item['hierarchy_type'].to_i != 3 }

puts "\nTotal Assembla ticket epics: #{@tickets_assembla_epic_h.length + @tickets_assembla_epic_s.length}"
puts "* hierarchy (#{@tickets_assembla_epic_h.length})"
puts "* summary (#{@tickets_assembla_epic_s.length})"
# Jira tickets

# jira-tickets.csv: result,retries,message,jira_ticket_id,jira_ticket_key,project_id,summary,issue_type_id,
# issue_type_name, assignee_name,reporter_name,priority_name,status_name,labels,description,assembla_ticket_id,
# assembla_ticket_number,custom_field,milestone_name,story_rank
tickets_jira_csv = "#{OUTPUT_DIR_JIRA}/jira-tickets.csv"
@tickets_jira = csv_to_array(tickets_jira_csv)
@total_jira_tickets = @tickets_jira.length

puts "\nTotal Jira tickets: #{@total_jira_tickets}"

@epic_names = {}
@tickets_with_epics = []
@tickets_jira.each do |ticket|
  epic_name = ticket['custom_field']
  if epic_name && epic_name.length.positive?
    @epic_names[epic_name] = 0 unless @epic_names[epic_name]
    @epic_names[epic_name] += 1
    @tickets_with_epics << ticket
  end
end

@total_epic_names = @epic_names.length
@total_tickets_with_epics = @tickets_with_epics.length

unless @total_epic_names.positive?
  puts 'No epics found (local) => SKIP'
  exit
end

puts "\nTotal Jira tickets with epic: #{@total_tickets_with_epics}"

puts "\nTotal epics (local): #{@total_epic_names}"
@epic_names.keys.sort.each do |k|
  puts "* #{k} (#{@epic_names[k]})"
end
puts

# GET /rest/agile/1.0/board/{boardId}/epic
def jira_get_epics(board)
  board_id = board['id']
  start_at = 0
  max_results = 50
  is_last = false
  epics = []
  headers = if JIRA_SERVER_TYPE == 'hosted'
              JIRA_HEADERS
            else
              JIRA_HEADERS_CLOUD
            end
  until is_last
    url = "#{URL_JIRA_BOARDS}/#{board_id}/epic?startAt=#{start_at}&maxResults=#{max_results}"
    begin
      response = RestClient::Request.execute(method: :get, url: url, headers: headers)
      json = JSON.parse(response)
      is_last = json['isLast']
      values = json['values']
      count = values.length
      if count.positive?
        values.each do |epic|
          epics << epic
        end
      end
      start_at += max_results
      puts "GET #{url} => ok (#{count})"
    rescue RestClient::ExceptionWithResponse => e
      rest_client_exception(e, 'GET', url)
    rescue => e
      puts "GET #{url} => nok (#{e.message})"
    end
  end
  epics
end

# Issues for epic
# GET /rest/agile/1.0/board/{boardId}/epic/{epicId}/issue
def jira_get_issues_for_epic(board, epic)
  board_id = board['id']
  epic_id = epic['id']
  start_at = 0
  max_results = 50
  is_last = false
  issues = []
  headers = if JIRA_SERVER_TYPE == 'hosted'
              JIRA_HEADERS
            else
              JIRA_HEADERS_CLOUD
            end
  until is_last
    url = "#{URL_JIRA_BOARDS}/#{board_id}/epic/#{epic_id}/issue?startAt=#{start_at}&maxResults=#{max_results}"
    begin
      response = RestClient::Request.execute(method: :get, url: url, headers: headers)
      json = JSON.parse(response)
      values = json['issues']
      count = values.length
      if count.positive?
        values.each do |issue|
          issues << issue
        end
      else
        is_last = true
      end
      start_at += max_results
      # puts "GET #{url} => ok (#{count})"
    rescue RestClient::ExceptionWithResponse => e
      rest_client_exception(e, 'GET', url)
    rescue => e
      puts "GET #{url} => nok (#{e.message})"
    end
  end
  issues
end

# Issues without an epic
# GET /rest/agile/1.0/board/{boardId}/epic/none/issue
def jira_get_issues_without_epic(board)
  board_id = board['id']
  start_at = 0
  max_results = 50
  is_last = false
  issues = []
  headers = if JIRA_SERVER_TYPE == 'hosted'
              JIRA_HEADERS
            else
              JIRA_HEADERS_CLOUD
            end
  until is_last
    url = "#{URL_JIRA_BOARDS}/#{board_id}/epic/none/issue?startAt=#{start_at}&maxResults=#{max_results}"
    begin
      response = RestClient::Request.execute(method: :get, url: url, headers: headers)
      json = JSON.parse(response)
      values = json['issues']
      count = values.length
      if count.positive?
        values.each do |issue|
          issues << issue
        end
      else
        is_last = true
      end
      start_at += max_results
      puts "GET #{url} => ok (#{count})"
    rescue RestClient::ExceptionWithResponse => e
      rest_client_exception(e, 'GET', url)
    rescue => e
      puts "GET #{url} => nok (#{e.message})"
    end
  end
  issues
end

board = jira_get_board_by_project_name(JIRA_API_PROJECT_NAME)
puts
goodbye('Cannot find board name') unless board

epics = jira_get_epics(board)
total_epics = epics.length

if total_epics.zero?
  puts 'No epics found (remote) => SKIP'
  exit
end

epics.sort! { |x, y| x['name'] <=> y['name'] }

puts "\nTotal epics (remote): #{total_epics}"
epics.each do |epic|
  name = epic['name']
  issues = jira_get_issues_for_epic(board, epic)
  id = epic['id']
  puts "* #{id} #{name} => #{issues.length} issues"
end
puts

issues_without_epic = jira_get_issues_without_epic(board)

puts "\nTotal Jira issues without epic: #{issues_without_epic.length}"
