# frozen_string_literal: true

### EXPERIMENTAL

load './lib/common.rb'

puts 'This is still in the EXPERIMENTAL phase.'

# Jira tickets

# jira-tickets.csv: result,retries,message,jira_ticket_id,jira_ticket_key,project_id,summary,issue_type_id,
# issue_type_name, assignee_name,reporter_name,priority_name,status_name,labels,description,assembla_ticket_id,
# assembla_ticket_number,theme_name,milestone_name,story_rank
tickets_jira_csv = "#{OUTPUT_DIR_JIRA}/jira-tickets.csv"
@tickets_jira = csv_to_array(tickets_jira_csv)
@total_jira_tickets = @tickets_jira.length

@epic_names = {}
@tickets_with_epics = []
@tickets_jira.each do |ticket|
  epic_name = ticket['theme_name']
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

puts "\nTotal tickets with epics: #{@total_tickets_with_epics}"

puts "\nTotal epics (local): #{@total_epic_names}"
@epic_names.keys.sort.each do |k|
  puts "* #{k} (#{@epic_names[k]})"
end
puts

# GET /rest/agile/1.0/board/{boardId}/epic
def jira_get_epics(board)
  board_id = board['id']
  results = []
  headers = if JIRA_SERVER_TYPE == 'hosted'
              JIRA_HEADERS
            else
              JIRA_HEADERS_CLOUD
            end
  url = "#{URL_JIRA_BOARDS}/#{board_id}/epic"
  begin
    response = RestClient::Request.execute(method: :get, url: url, headers: headers)
    json = JSON.parse(response)
    values = json['values']
    count = values.length
    if count.positive?
      values.each do |result|
        results << result
      end
    end
    puts "GET #{url} => ok (#{count})"
  rescue RestClient::ExceptionWithResponse => e
    rest_client_exception(e, 'GET', url)
  rescue => e
    puts "GET #{url} => nok (#{e.message})"
  end
  results
end

board = jira_get_board_by_project_name(JIRA_API_PROJECT_NAME)

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
  puts "* #{name}"
end

