# frozen_string_literal: true

load './lib/common.rb'

def jira_get_screen_tabs(project_key, screen_id)
  url = "#{URL_JIRA_SCREENS}/#{screen_id}/tabs?projectKey=#{project_key}"
  result = nil
  begin
    response = RestClient::Request.execute(method: :get, url: url, headers: JIRA_HEADERS_ADMIN)
    result = JSON.parse(response.body)
  rescue => e
    puts "GET #{url} => NOK (#{e.message})"
  end
  result
end

def jira_get_screen_available_fields(project_key, screen_id)
  url = "#{URL_JIRA_SCREENS}/#{screen_id}/availableFields?projectKey=#{project_key}"
  result = nil
  begin
    response = RestClient::Request.execute(method: :get, url: url, headers: JIRA_HEADERS_ADMIN)
    result = JSON.parse(response.body)
  rescue => e
    puts "GET #{url} => NOK (#{e.message})"
  end
  result
end

def jira_get_screen_tab_fields(project_key, screen_id, tab_id)
  url = "#{URL_JIRA_SCREENS}/#{screen_id}/tabs/#{tab_id}/fields?projectKey=#{project_key}"
  result = nil
  begin
    response = RestClient::Request.execute(method: :get, url: url, headers: JIRA_HEADERS_ADMIN)
    result = JSON.parse(response.body)
  rescue => e
    puts "GET #{url} => NOK (#{e.message})"
  end
  result
end

# POST /rest/api/2/screens/{screenId}/tabs/{tabId}/fields
# {
#     "fieldId": "summary"
# }
def jira_add_field(screen_id, tab_id, field_id)
  url = "#{URL_JIRA_SCREENS}/#{screen_id}/tabs/#{tab_id}/fields"
  payload = {
    fieldId: field_id
  }.to_json
  result = nil
  begin
    response = RestClient::Request.execute(method: :post, url: url, payload: payload, headers: JIRA_HEADERS_ADMIN)
    result = JSON.parse(response.body)
    puts "POST #{url} => OK"
  rescue => e
    puts "POST #{url} => NOK (#{e.message})"
  end
  result
end

# --- JIRA fields --- #

@fields_jira = jira_get_fields
goodbye('Cannot get fields!') unless @fields_jira

def jira_get_field_by_name(name)
  @fields_jira.find{ |field| field['name'] == name }
end

# --- JIRA screens --- #

project = jira_get_project_by_name(JIRA_API_PROJECT_NAME)

@all_custom_field_names = CUSTOM_FIELD_NAMES.dup
@all_custom_field_names << "Assembla-#{ASSEMBLA_CUSTOM_FIELD}" unless ASSEMBLA_CUSTOM_FIELD&.empty?

unless ARGV.length == 2
  goodbye('Missing screens ids, ARGV1=screen_id1 and ARGV2=screen_id2 (see README.md)')
end
goodbye("Invalid ARGV1='#{ARGV[0]}', must be a number") unless /^\d+$/.match?(ARGV[0])
goodbye("Invalid ARGV2='#{ARGV[1]}', must be a number") unless /^\d+$/.match?(ARGV[1])

@screens = [{ id: ARGV[0] }, { id: ARGV[1] }]

@screens.each do |screen|
  screen[:availableFields] = jira_get_screen_available_fields(project['key'], screen[:id])
  unless screen[:availableFields]
    goodbye("Looks like screen_id='#{screen[:id]}' doesn't exist")
  end
  screen[:tabs] = jira_get_screen_tabs(project['key'], screen[:id])
  unless screen[:tabs].length.positive?
    goodbye("Looks like screen_id='#{screen[:id]}' has no tabs")
  end
  screen[:tabs].each do |tab|
    tab[:fields] = jira_get_screen_tab_fields(project['key'], screen[:id], tab['id'])
  end
end

@all_custom_field_names.each do |name|
  @screens.each do |screen|
    next unless screen[:availableFields].detect { |field| name.casecmp(field['name']) == 0 }
    field = jira_get_field_by_name(name)
    result = jira_add_field(screen[:id], screen[:tabs][0]['id'],field['id'])
    goodbye("Cannot add field='#{name}'") unless result
  end
end

puts
@screens.each do |screen|
  tab = screen[:tabs][0]
  puts "Screen: id=#{screen[:id]}"
  puts "Tab: id='#{tab['id']}', name='#{tab['name']}' fields=#{tab[:fields].length}"
  tab[:fields].sort { |x, y| x['name'] <=> y['name'] }.each do |field|
    puts "* '#{field['name']}' #{field['id']} #{field['type']}" if @all_custom_field_names.include?(field['name'])
  end
end
