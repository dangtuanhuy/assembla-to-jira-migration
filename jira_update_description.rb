# frozen_string_literal: true

load './lib/common.rb'

def jira_update_description(issue_id, description)
  result = nil
  url = "#{URL_JIRA_ISSUES}/#{issue_id}?notifyUsers=false"
  fields = {}
  fields[:description] = description
  payload = {
      update: {},
      fields: fields
  }.to_json
  begin
    RestClient::Request.execute(method: :put, url: url, payload: payload, headers: JIRA_HEADERS_ADMIN)
    puts "PUT #{url} description => OK"
    result = true
  rescue RestClient::ExceptionWithResponse => e
    rest_client_exception(e, 'PUT', url, payload)
  rescue => e
    puts "PUT #{url} description => NOK (#{e.message})"
  end
  result
end

def jira_get_issue_fields(issue_id, fields)
  result = nil
  url = "#{URL_JIRA_ISSUES}/#{issue_id}?#{fields.join('&')}"
  begin
    response = RestClient::Request.execute(method: :get, url: url, headers: JIRA_HEADERS_ADMIN)
    result = JSON.parse(response.body)
    if result
      result.delete_if { |k, _| k =~ /self|expand/i }
      puts "GET #{url} => OK"
    end
  rescue RestClient::ExceptionWithResponse => e
    rest_client_exception(e, 'GET', url)
  rescue => e
    puts "GET #{url} => NOK (#{e.message})"
  end
  result
end

# DUMMY
issue_id = 'OOPM-2695'

results = jira_get_issue_fields(issue_id, ['description'])

description = results['fields']['description']

description += "\n\n !Fry.png!"
description += "\n\n !image.2020.png!"

jira_update_description(issue_id, description)
