# frozen_string_literal: true

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

