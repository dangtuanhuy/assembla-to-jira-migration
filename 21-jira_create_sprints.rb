# frozen_string_literal: true

load './lib/common.rb'

MILESTONE_PLANNER_TYPES = %w(none backlog current unknown).freeze

# --- Assembla --- #
assembla_milestones_csv = "#{OUTPUT_DIR_ASSEMBLA}/milestones-all.csv"
@milestones_assembla = csv_to_array(assembla_milestones_csv)

puts "\nTotal milestones: #{@milestones_assembla.length}"

# --- Jira --- #
projects_jira_csv = "#{OUTPUT_DIR_JIRA}/jira-projects.csv"
tickets_jira_csv = "#{OUTPUT_DIR_JIRA}/jira-tickets.csv"

@projects_jira = csv_to_array(projects_jira_csv)
@tickets_jira = csv_to_array(tickets_jira_csv).select { |ticket| ticket['result'] == 'OK' }

# milestone: id,start_date,due_date,budget,title,user_id,created_at,created_by,space_id,description,is_completed,
# completed_date,updated_at,updated_by,release_level,release_notes,planner_type,pretty_release_level
@milestones_assembla.each do |milestone|
  puts "* #{milestone['id']} #{milestone['title']} (#{MILESTONE_PLANNER_TYPES[milestone['planner_type'].to_i]})" \
       " => #{milestone['is_completed'] ? '' : 'not'} completed"
end
puts

# The following line will select 'sprints' from the milestones for those milestones explicitly
# containing the string 'sprint' in them. If you choose to convert all milestones into
# sprints then replace the following line with:
@sprints = @milestones_assembla
# @sprints = @milestones_assembla.select { |milestone| milestone['title'] =~ /sprint/i }

# Need to sort the sprints so that they appear in the correct order.
@sprints.sort! { |x, y| y['start_date'].to_s <=> x['start_date'].to_s }

puts "Total sprints: #{@sprints.length}"

# Important: Jira sprint names cannot be longer than 30 characters.
@sprints.each do |sprint|
  puts "* #{sprint['title']}"
end
puts

# Sprint name must be shorter than 30 characters
def get_name(name)
  name.length > 29 ? name[0...26] + '...' : name
end

# You must specify a start date for the sprint
def get_start_date(startDate, endDate)
  if startDate.nil?
    if endDate.nil?
      y, m, d = Time.now().to_s[0...10].split('-')
    else
      y, m, d = endDate[0...10].split('-')
    end
    # 14 days before the end date or today if no start date
    (Time.gm(y, m, d) - (14 * 24 * 60 * 60)).to_s[0...10]
  else
    startDate
  end
end

# You must specify an end date for the sprint
def get_end_date(startDate, endDate)
  # You must specify a start date for the sprint
  if endDate.nil?
    if startDate.nil?
      y, m, d = Time.now().to_s[0...10].split('-')
    else
      y, m, d = startDate[0...10].split('-')
    end
    # 14 days after the start date or today if no start date
    (Time.gm(y, m, d) + (14 * 24 * 60 * 60)).to_s[0...10]
  else
    endDate
  end
end

# GET /rest/agile/1.0/board/{boardId}/sprint
def jira_get_sprint(board, sprint)
  result = nil
  name = get_name(sprint['title'])
  url = "#{URL_JIRA_BOARDS}/#{board['id']}/sprint"
  begin
    response = RestClient::Request.execute(method: :get, url: url, headers: JIRA_HEADERS_ADMIN)
    body = JSON.parse(response.body)
    # max_results = body['maxResults'].to_i
    # start_at = body['startAt'].to_i
    # is_last = body['isLast']
    values = body['values']
    if values
      result = values.detect { |h| h['name'] == name }
      if result
        result.delete_if { |k, _| k =~ /self/i }
        puts "GET #{url} name='#{name}' => FOUND"
      else
        puts "GET #{url} name='#{name}' => NOT FOUND"
      end
    end
  rescue => e
    puts "GET #{url} name='#{name}' => NOK (#{e.message})"
  end
  result
end

def jira_create_sprint(board, sprint)
  result = nil
  name = get_name(sprint['title'])
  startDate = sprint['start_date']
  endDate = sprint['due_date']
  startDate = get_start_date(startDate, endDate)
  endDate = get_end_date(startDate, endDate)
  url = URL_JIRA_SPRINTS
  payload = {
    name: name,
    startDate: startDate,
    endDate: endDate,
    originBoardId: board['id']
    # "goal": "sprint 1 goal"
  }.to_json
  begin
    response = RestClient::Request.execute(method: :post, url: url, payload: payload, headers: JIRA_HEADERS_ADMIN)
    result = JSON.parse(response.body)
    if result
      result.delete_if { |k, _| k =~ /self/i }
      puts "POST #{url} name='#{name}' => OK"
    end
  rescue RestClient::ExceptionWithResponse => e
    rest_client_exception(e, 'POST', url, payload)
  rescue => e
    puts "POST #{url} name='#{name}' => NOK (#{e.message})"
  end
  result
end

# POST /rest/agile/1.0/sprint/{sprintId}/issue
def jira_move_issues_to_sprint(sprint, tickets)
  # Moves issues to a sprint, for a given sprint Id. Issues can only be moved to open or active sprints. The maximum
  # number of issues that can be moved in one operation is 50.
  len = tickets.length
  goodbye("Cannot move issues to sprint, len=#{len} (must be less than 50") if len > 50
  result = nil
  url = "#{URL_JIRA_SPRINTS}/#{sprint['id']}/issue"
  issues = tickets.map { |ticket| ticket['jira_ticket_key'] }.compact
  payload = {
    issues: issues
  }.to_json
  begin
    # For a dry-run, comment out the following line
    RestClient::Request.execute(method: :post, url: url, payload: payload, headers: JIRA_HEADERS_ADMIN)
    puts "POST #{url} name='#{sprint['name']}' #{issues.length} issues [#{issues.join(',')}] => OK"
    result = true
  rescue RestClient::ExceptionWithResponse => e
    rest_client_exception(e, 'POST', url, payload)
  rescue => e
    puts "POST #{url} => NOK (#{e.message})"
  end
  result
end

# PUT /rest/agile/1.0/sprint/{sprintId}
def jira_update_sprint_state(sprint, state)
  result = nil
  name = get_name(sprint['name'])
  startDate = sprint['startDate']
  endDate = sprint['endDate']
  startDate = get_start_date(startDate, endDate)
  endDate = get_end_date(startDate, endDate)
  url = "#{URL_JIRA_SPRINTS}/#{sprint['id']}"
  payload = {
    name: name,
    state: state,
    startDate: startDate,
    endDate: endDate
  }.to_json
  begin
    RestClient::Request.execute(method: :put, url: url, payload: payload, headers: JIRA_HEADERS_ADMIN)
    puts "PUT #{url} name='#{name}', state='#{state}' => OK"
    result = true
  rescue RestClient::ExceptionWithResponse => e
    rest_client_exception(e, 'PUT', url, payload)
  rescue => e
    puts "PUT #{url} name='#{name}', state='#{state}' => NOK (#{e.message})"
  end
  result
end

project = @projects_jira.detect { |p| p['name'] == JIRA_API_PROJECT_NAME }
goodbye("Cannot find project with name='#{JIRA_API_PROJECT_NAME}'") unless project

@board = jira_get_board_by_project_name(JIRA_API_PROJECT_NAME)

@jira_sprints = []

# sprint: id,start_date,due_date,budget,title,user_id,created_at,created_by,space_id,description,is_completed,
# completed_date,updated_at,updated_by,release_level,release_notes,planner_type,pretty_release_level
# next_sprint: id,state,name,startDate,endDate,originBoardId,assembla_id
@sprints.each do |sprint|
  next_sprint = jira_get_sprint(@board, sprint) || jira_create_sprint(@board, sprint)
  next unless next_sprint
  @tickets_sprint = @tickets_jira.select { |ticket| ticket['milestone_name'] == sprint['title'] }
  issues = @tickets_sprint.map { |ticket| ticket['jira_ticket_key'] }
  while @tickets_sprint.length.positive?
    @tickets_sprint_slice = @tickets_sprint.slice!(0, 50)
    # For a dry-run, comment out the following two lines
    jira_update_sprint_state(next_sprint, 'active')
    jira_move_issues_to_sprint(next_sprint, @tickets_sprint_slice)
  end
  @jira_sprints << next_sprint.merge(issues: issues.join(',')).merge(assembla_id: sprint['id'])
end

# First sprint should be 'active' and the other 'closed'
# For a dry-run, comment out the following line
jira_update_sprint_state(@jira_sprints.first, 'active') if @jira_sprints.length > 0

puts "\nTotal updates: #{@jira_sprints.length}"
sprints_jira_csv = "#{OUTPUT_DIR_JIRA}/jira-sprints.csv"
# For a dry-run, comment out the following line
write_csv_file(sprints_jira_csv, @jira_sprints)
