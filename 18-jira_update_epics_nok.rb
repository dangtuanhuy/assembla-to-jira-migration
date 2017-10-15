# frozen_string_literal: true

### EXPERIMENTAL

load './lib/common.rb'

updated_epics_jira_csv = "#{OUTPUT_DIR_JIRA}/jira-update-epics.csv"
@updated_epics_jira = csv_to_array(updated_epics_jira_csv)

@epics_nok = @updated_epics_jira.select { |epic| epic['result'] == 'NOK' }
@epics_nok_total = @epics_nok.length

# POST /rest/agile/1.0/epic/{epicIdOrKey}/issue
# The maximum number of issues that can be moved in one operation is 50.
def jira_move_stories_to_epic(epic, story_key, counter, total)
  result = {
    result: false,
    error: ''
  }
  epic_key = epic['jira_key']
  url = "#{URL_JIRA_EPICS}/#{epic_key}/issue"
  payload = {
    issues: [story_key]
  }.to_json
  headers = JIRA_SERVER_TYPE == 'hosted' ? JIRA_HEADERS : JIRA_HEADERS_CLOUD
  begin
    RestClient::Request.execute(method: :post, url: url, payload: payload, headers: headers)
    percentage = ((counter * 100) / total).round.to_s.rjust(3)
    puts "#{percentage}% [#{counter}|#{total}] POST #{url} #{story_key} => OK"
    result[:result] = true
  rescue RestClient::ExceptionWithResponse => e
    result[:error] = rest_client_exception(e, 'POST', url)
  rescue => e
    puts "#{percentage}% [#{counter}|#{total}] POST #{url} #{story_key} => NOK (#{e.message})"
    result[:error] = e.message
  end
  result
end

puts "\nMoving stories to epics"
@updated_epics_nok = []
@epics_nok.each_with_index do |epic, index|
  story_keys = epic['story_keys'][1..-2].split(',')
  story_keys.each_with_index do |story_key|
    result = jira_move_stories_to_epic(epic, story_key, index + 1, @epics_nok_total)
    @updated_epics_nok << {
      result: result[:result] ? 'OK' : 'NOK',
      epic_nr: epic['epic_nr'],
      jira_key: epic['jira_key'],
      stories: 1,
      story_keys: "[#{story_key}]",
      error: result[:error]
    }
  end
end

puts "Total updated epics: #{@updated_epics_nok.length}"
updated_epics_nok_jira_csv = "#{OUTPUT_DIR_JIRA}/jira-update-epics-nok.csv"
write_csv_file(updated_epics_nok_jira_csv, @updated_epics_nok)
