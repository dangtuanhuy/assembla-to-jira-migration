# frozen_string_literal: true

load './lib/common.rb'

# --- Assembla --- #
assembla_statuses_csv = "#{OUTPUT_DIR_ASSEMBLA}/tickets-statuses.csv"
@statuses_assembla = csv_to_array(assembla_statuses_csv)

@from_to = {}
@columns_needed = []
JIRA_API_STATUSES.split(',').each do |status|
  from, to = status.split(':')
  to ||= from
  @from_to[from.downcase] = to
end

@board_columns = @statuses_assembla.reject { |status| status['state'].to_i.zero? }.map {|status| { id: status['id'], name: status['name']}}

puts "\nBoard columns needed: #{@board_columns.length}"
@board_columns.each do |col|
  to = @from_to[col[:name].downcase]
  @columns_needed << to unless @columns_needed.include?(to)
  puts "* #{col[:name]} => #{to}"
end
puts

# --- Jira --- #
jira_projects_csv = "#{OUTPUT_DIR_JIRA}/jira-projects.csv"
jira_tickets_csv = "#{OUTPUT_DIR_JIRA}/jira-tickets.csv"


@projects_jira = csv_to_array(jira_projects_csv)
@tickets_jira = csv_to_array(jira_tickets_csv)

project = @projects_jira.detect { |p| p['name'] == JIRA_API_PROJECT_NAME }
goodbye("Cannot find project with name='#{JIRA_API_PROJECT_NAME}'") unless project

# GET /rest/agile/1.0/board/{boardId}/configuration
def jira_get_board_config(board)
  result = nil
  url = "#{URL_JIRA_BOARDS}/#{board['id']}/configuration"
  begin
    response = RestClient::Request.execute(method: :get, url: url, headers: JIRA_HEADERS)
    result = JSON.parse(response)
    if result
      result.each do |r|
        r.delete_if { |k, _| k.to_s =~ /self/i }
      end
      puts "GET #{url} => OK (#{result.length})"
    end
  rescue => e
    puts "GET #{url} => NOK (#{e.message})"
  end
  result
end

@board = jira_get_board_by_project_name(JIRA_API_PROJECT_NAME)

goodbye('Cannot find board name') unless @board

config = jira_get_board_config(@board)

@columns_actual = config['columnConfig']['columns']

puts "\nBoard columns actual: #{@columns_actual.length}"
@columns_actual.each do |column|
  puts "* #{column['name']}"
end

@columns_missing = []
@columns_needed.each do |column_needed|
  @columns_missing << column_needed unless @columns_actual.detect { |column_actual| column_actual['name'].casecmp(column_needed).zero? }
end

if @columns_missing.length.positive?
  puts "\nGo to Configure '#{@board['name']} | Column Management' and add the following columns:"
  @columns_missing.each do |column_missing|
    puts "* #{column_missing}"
  end
  puts "\nlink: #{JIRA_API_BASE}/secure/RapidView.jspa?rapidView=3&tab=columns"
end
