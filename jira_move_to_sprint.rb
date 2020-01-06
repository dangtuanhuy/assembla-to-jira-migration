# frozen_string_literal: true

load './lib/common.rb'

@board = jira_get_board_by_project_name(JIRA_API_PROJECT_NAME)

# GET /rest/agile/1.0/board/{boardId}/sprint
def jira_get_sprints(board)
  result = []
  start_at = 0
  max = 50
  is_last = false
  until is_last
    url = "#{URL_JIRA_BOARDS}/#{board['id']}/sprint?startAt=#{start_at}"
    begin
      response = RestClient::Request.execute(method: :get, url: url, headers: JIRA_HEADERS_ADMIN)
      body = JSON.parse(response.body)
      start_at = body['startAt'].to_i + max
      is_last = body['isLast']
      count = body['values'].length
      body['values'].each do |value|
        result << value
      end
      puts "GET #{url} => OK (#{count})"
    rescue => e
      puts "GET #{url} => NOK (#{e.message})"
      is_last = false
    end
  end
  result
end

# PUT /rest/agile/1.0/sprint/{sprintId}
def jira_update_sprint_state(sprint, state)
  result = false
  name = sprint['name']
  startDate = sprint['startDate']
  endDate = sprint['endDate']
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

# POST /rest/agile/1.0/sprint/{sprintId}/issue
def jira_move_issue_to_sprint(key, sprint)
  result = false
  id = sprint['id']
  name = sprint['name']
  state = sprint['state']
  url = "#{URL_JIRA_SPRINTS}/#{id}/issue"
  payload = {
      issues: [key]
  }.to_json
  begin
    RestClient::Request.execute(method: :post, url: url, payload: payload, headers: JIRA_HEADERS_ADMIN)
    puts "POST #{url} name='#{name}' state='#{state}' key='#{key}' => OK"
    result = true
  rescue RestClient::ExceptionWithResponse => e
    rest_client_exception(e, 'POST', url, payload)
  rescue => e
    puts "POST #{url} name='#{name}' state='#{state}' key='#{key}' => NOK (#{e.message})"
  end
  result
end

@jira_sprints = jira_get_sprints(@board)

# The following issues need to be moved to the given sprints. Note that if a given sprint
# is 'closed' that it must first be changed to 'active' and then restored to 'closed' when
# no longer needed.
@issues = [
    { key: 'OOPM-1999', sprint: 'Operations', state: '' },
    { key: 'OOPM-2294', sprint: 'Sprint#49/R3.0', state: '' },
    { key: 'OOPM-2308', sprint: 'Sprint#49/R3.0', state: '' },
    { key: 'OOPM-2342', sprint: 'Sprint#48/R3.0', state: '' },
    { key: 'OOPM-2446', sprint: 'Sprint#58/R3.1', state: '' }
]

# Save current state of sprint to be restored later
@issues.each do |issue|
  key = issue[:key]
  name = issue[:sprint]
  sprint = @jira_sprints.detect { |s| s['name'] == name }
  if sprint
    state = sprint['state']
    issue[:state] = state
    if state == 'closed'
      sprint['state'] = 'active' if jira_update_sprint_state(sprint, 'active')
    end
  else
    puts "key='#{key}' name='#{name}' => NOK"
  end
end

# Move issues to new sprints
@issues.each do |issue|
  key = issue[:key]
  name = issue[:sprint]
  sprint = @jira_sprints.detect { |s| s['name'] == name }
  if sprint
    jira_move_issue_to_sprint(key, sprint)
  else
    puts "key='#{key}' name='#{name}' => NOK"
  end
end

# Restore original state of sprint
@issues.each do |issue|
  key = issue[:key]
  name = issue[:sprint]
  sprint = @jira_sprints.detect { |s| s['name'] == name }
  if sprint
    curr_state = sprint['state']
    prev_state = issue[:state]
    if prev_state != curr_state
      sprint['state'] = prev_state if jira_update_sprint_state(sprint, prev_state)
    end
    jira_update_sprint_state(sprint, 'closed')
  else
    puts "key='#{key}' name='#{name}' => NOK"
  end
end
