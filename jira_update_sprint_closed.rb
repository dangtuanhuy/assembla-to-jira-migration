# frozen_string_literal: true

load './lib/common.rb'

@board = jira_get_board_by_project_name(JIRA_API_PROJECT_NAME)

# Sprint name must be shorter than 30 characters
def get_name(name)
  name.length > 29 ? name[0...26] + '...' : name
end

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
  result = nil
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

current_sprint = 'Sprint#85/R4.1'
@ignore = %w{Operations Archive Backlog}

@jira_sprints = jira_get_sprints(@board)

@jira_sprints.each do |sprint|
  name = sprint['name']
  puts name
  id = sprint['id'].to_i
  next if @ignore.include?(name)
  #next unless [145, 148, 158, 214, 215, 221].include?(id)
  #next unless [221].include?(id)
  #jira_update_sprint_state(sprint, name == current_sprint ? 'active' : 'closed')
  #jira_update_sprint_state(sprint, 'open')
end

