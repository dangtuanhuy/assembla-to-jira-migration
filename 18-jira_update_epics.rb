# frozen_string_literal: true

### EXPERIMENTAL

load './lib/common.rb'

### --- Assembla tickets --- ###

# tickets.csv: id,number,summary,description,priority,completed_date,component_id,created_on,permission_type,
# importance,is_story,milestone_id,notification_list,space_id,state,status,story_importance,updated_at,working_hours,
# estimate,total_estimate,total_invested_hours,total_working_hours,assigned_to_id,reporter_id,custom_fields,
# hierarchy_type,due_date,assigned_to_name,picture_url
tickets_assembla_csv = "#{OUTPUT_DIR_ASSEMBLA}/tickets.csv"
@tickets_assembla = csv_to_array(tickets_assembla_csv)

@a_id_to_a_nr = {}
@a_id_to_a_is = {}
@a_id_to_a_ht = {}
@tickets_assembla.each do |ticket|
  id = ticket['id'].to_i
  @a_id_to_a_nr[id] = ticket['number']
  @a_id_to_a_is[id] = ticket['is_story']
  @a_id_to_a_ht[id] = ticket['hierarchy_type']
end

# ticket-associations.csv: id,ticket1_id,ticket2_id,relationship,created_at,ticket_id,ticket_number,relationship_name
associations_assembla_csv = "#{OUTPUT_DIR_ASSEMBLA}/ticket-associations.csv"
@asociations_assembla = csv_to_array(associations_assembla_csv)

# --- Filter by date if TICKET_CREATED_ON is defined --- #
tickets_created_on = get_tickets_created_on

if tickets_created_on
  puts "Filter newer than: #{tickets_created_on}"
  tickets_initial = @tickets_assembla.length
  @tickets_assembla.select! { |item| item_newer_than?(item, tickets_created_on) }
  puts "Total Assembla tickets: #{tickets_initial} => #{@tickets_assembla.length} ∆#{tickets_initial - @tickets_assembla.length}"
else
  puts "\nTotal Assembla tickets: #{@tickets_assembla.length}"
end

# hierarchy_type => epic
@tickets_assembla_epic_h = @tickets_assembla.select do |epic_h| 
  hierarchy_type_epic(epic_h['hierarchy_type']) && 
    epic_h['summary'] !~ /^(spike|bug)/i
end
@tickets_assembla_epic_s = @tickets_assembla.select do |epic_s|
  hierarchy_type_epic(epic_s['hierarchy_type']) &&
    !@tickets_assembla_epic_h.detect { |epic_h| epic_h['id'].to_i == epic_s['id'].to_i }
end

puts "\nTotal Assembla epics: #{@tickets_assembla_epic_h.length} + #{@tickets_assembla_epic_s.length} = #{@tickets_assembla_epic_h.length + @tickets_assembla_epic_s.length}"

### --- Jira tickets --- ###

# jira-tickets.csv: result,retries,message,jira_ticket_id,jira_ticket_key,project_id,summary,issue_type_id,
# issue_type_name, assignee_name,reporter_name,priority_name,status_name,labels,description,assembla_ticket_id,
# assembla_ticket_number,custom_field,milestone_name,story_rank
tickets_jira_csv = "#{OUTPUT_DIR_JIRA}/jira-tickets.csv"
@tickets_jira = csv_to_array(tickets_jira_csv)

puts "\nTotal Jira tickets: #{@tickets_jira.length}"

@tickets_jira_epics = @tickets_jira.select do |jira_ticket|
  @tickets_assembla_epic_h.detect { |assembla_ticket| assembla_ticket['id'].to_i == jira_ticket['assembla_ticket_id'].to_i } ||
    @tickets_assembla_epic_s.detect { |assembla_ticket| assembla_ticket['id'].to_i == jira_ticket['assembla_ticket_id'].to_i }
end

puts "\nTotal Jira epics: #{@tickets_jira_epics.length}"

@a_id_to_j_id = {}
@a_nr_to_j_key = {}
@tickets_jira.each do |ticket|
  id = ticket['assembla_ticket_id'].to_i
  nr = ticket['assembla_ticket_number'].to_i
  @a_id_to_j_id[id] = ticket['jira_ticket_id']
  @a_nr_to_j_key[nr] = ticket['jira_ticket_key']
end

@epics_with_stories = []

def epic_overview(epic)
  epic_with_stories = nil
  epic_id = epic['id'].to_i
  epic_nr = epic['number'].to_i
  children = @asociations_assembla.select do |association|
    epic['id'].to_i == association['ticket_id'].to_i && association['relationship_name'] == 'parent'
  end
  nr = children.length
  plural = nr == 1 ? 'story' : 'stories'
  jira_id = (@a_id_to_j_id[epic_id] || 0).to_i
  jira_key = @a_nr_to_j_key[epic_nr] || 'unknown'
  if nr.positive?
    epic_with_stories = {
      epic_id: epic_id,
      epic_nr: epic_nr,
      jira_id: jira_id,
      jira_key: jira_key,
      stories: []
    }
  end
  summary = epic['summary']
  summary = "#{summary [0..50]}..." if summary.length > 53
  puts "Epic #{epic_id}|#{epic_nr}|#{jira_id}|#{jira_key} has #{children.length} #{plural} '#{summary}'"
  children.each do |child|
    ticket_id = child['ticket1_id'].to_i
    ticket_nr = (@a_id_to_a_nr[ticket_id] || 0).to_i
    story_id = @a_id_to_j_id[ticket_id] || 'unknwn'
    story_key = @a_nr_to_j_key[ticket_nr] || 'unknown'
    epic_with_stories[:stories] << {
      ticket_id: ticket_id,
      ticket_nr: ticket_nr,
      story_id: story_id,
      story_key: story_key
    }
    puts "* #{ticket_id}|#{ticket_nr}|#{story_id}|#{story_key}"
  end
  @epics_with_stories << epic_with_stories if epic_with_stories
end

puts "\nHierarchy (#{@tickets_assembla_epic_h.length}) => OK"
@tickets_assembla_epic_h.each do |epic|
  epic_overview(epic)
end

puts "\nSummary (#{@tickets_assembla_epic_s.length}) => OK"
@tickets_assembla_epic_s.each do |epic|
  epic_overview(epic)
end

@epics_with_stories.sort! { |x, y| x[:epic_id].to_i <=> y[:epic_id].to_i }
puts "\nTotal Jira epics with stories: #{@epics_with_stories.length}"
@epics_with_stories.each do |epic|
  nr = epic[:stories].length
  unique = @epics_with_stories.select { |epic2| epic2[:epic_id].to_i == epic[:epic_id].to_i }.length == 1
  puts "* #{epic[:epic_id]}|#{epic[:epic_nr]}|#{epic[:jira_id]}|#{epic[:jira_key]} => #{nr}#{unique ? '' : ' NOT UNIQUE!'}"
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

# POST /rest/agile/1.0/epic/{epicIdOrKey}/issue
def jira_move_stories_to_epic(epic, stories, counter, total)
  result = nil
  epic_id = epic[:epic_id]
  url = "#{URL_JIRA_EPICS}/#{epic_id}/issue"
  payload = {
    issues: stories
  }.to_json
  list = stories.map { |story| story.sub(/^[^\-]+\-/, '').to_i }
  headers = JIRA_SERVER_TYPE == 'hosted' ? JIRA_HEADERS : JIRA_HEADERS_CLOUD
  begin
    # RestClient::Request.execute(method: :post, url: url, payload: payload, headers: headers)
    percentage = ((counter * 100) / total).round.to_s.rjust(3)
    puts "#{percentage}% [#{counter}|#{total}] POST #{url} #{list} => OK"
  rescue RestClient::ExceptionWithResponse => e
    rest_client_exception(e, 'POST', url)
  rescue => e
    puts "#{percentage}% [#{counter}|#{total}] POST #{url} #{list} => NOK (#{e.message})"
  end
  result 
end

@board = jira_get_board_by_project_name(JIRA_API_PROJECT_NAME)
puts
goodbye('Cannot find board name') unless @board

@remote_epics = jira_get_epics(@board)

puts "\nTotal remote epics: #{@remote_epics.length}"

# Sanity check that all epics have been created.
@remote_epics_found = []
@remote_epics_not_found = []
@remote_epics.each do |remote_epic|
  key = remote_epic['key']
  if @tickets_jira_epics.detect { |epic| key == epic['jira_ticket_key'] }
    @remote_epics_found << remote_epic
  else
    @remote_epics_not_found << remote_epic
  end
end

puts "* Epics real (#{@remote_epics_found.length}) => #{@remote_epics_found.map { |epic| epic['key'] }}"
puts "* Epics converted (#{@remote_epics_not_found.length}) => #{@remote_epics_not_found.map { |epic| epic['key'] }}"

@local_epics_not_found = []
@tickets_jira_epics.each do |epic|
  key = epic['jira_ticket_key']
  unless @remote_epics_found.detect { |remote_epic| key == remote_epic['key'] }
    @local_epics_not_found << epic 
  end
end

# Another sanity check just in case
if @local_epics_not_found.length.positive?
  puts "\nEpics not found: #{@local_epics_not_found.length}"
  @local_epics_not_found.each do |epic|
    puts "* #{epic['jira_ticket_key']} '#{epic['summary']}'"
  end
  puts
end

puts "\nMoving stories to epics"
@total_epics_with_stories = @epics_with_stories.length
@updated_epics = []
@epics_with_stories.each_with_index do |epic, index|
  stories = epic[:stories].map { |story| story[:story_key]}
  results = jira_move_stories_to_epic(epic, stories, index + 1, @total_epics_with_stories)
end

puts "Total updated epics: #{@updated_epics.length}"
updated_epics_jira_csv = "#{OUTPUT_DIR_JIRA}/jira-update-epics.csv"
write_csv_file(updated_epics_jira_csv, @updated_epics)
