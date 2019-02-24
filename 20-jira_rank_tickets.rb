# frozen_string_literal: true

load './lib/common.rb'

# Jira tickets

# jira-tickets.csv: result,retries,message,jira_ticket_id,jira_ticket_key,project_id,summary,issue_type_id,
# issue_type_name, assignee_name,reporter_name,priority_name,status_name,labels,description,assembla_ticket_id,
# assembla_ticket_number,custom_field,milestone_name,story_rank
tickets_jira_csv = "#{OUTPUT_DIR_JIRA}/jira-tickets.csv"
@tickets_jira = csv_to_array(tickets_jira_csv).select { |ticket| ticket['result'] == 'OK' }
@total_jira_tickets = @tickets_jira.length

@is_ticket_key = {}
@tickets_jira.each do |ticket|
  @is_ticket_key[ticket['jira_ticket_key']] = true
end

# TEST
tickets_jira_csv_org = "#{OUTPUT_DIR_JIRA}/jira-tickets.csv"
csv_to_array(tickets_jira_csv_org).select { |ticket| ticket['result'] == 'OK' }.each do |t|
  @tickets_jira.push(t)
end
@total_jira_tickets = @tickets_jira.length
# TEST

# PUT /rest/agile/1.0/issue/rank
def jira_rank_issues(issues, after_issue, counter)
  result = nil
  url = URL_JIRA_ISSUE_RANKS
  payload = {
    issues: issues,
    rankAfterIssue: after_issue
  }.to_json
  percentage = ((counter * 100) / @total_jira_tickets).round.to_s.rjust(3)
  begin
    # For a dry-run, comment out the following line.
    RestClient::Request.execute(method: :put, url: url, payload: payload, headers: JIRA_HEADERS_ADMIN)
    puts "#{percentage}% [#{counter}|#{@total_jira_tickets}] PUT #{url} issues=#{issues} after=\"#{after_issue}\" => OK"
    result = true
  rescue RestClient::ExceptionWithResponse => e
    rest_client_exception(e, 'PUT', url, payload)
  rescue => e
    puts "#{percentage}% [#{counter}|#{@total_jira_tickets}] PUT #{url} issues=#{issues} after=\"#{after_issue}\" => NOK (#{e.message})"
  end
  result
end

@tickets_jira = @tickets_jira.sort { |x, y| x['story_rank'].to_i.round <=> y['story_rank'].to_i.round }

diff = 0 - @tickets_jira.first['story_rank'].to_i.round

@tickets_rank = @tickets_jira.map { |ticket| { rank: ticket['story_rank'].to_i.round + diff + 1, key: ticket['jira_ticket_key'] } }

@list = []
puts "\nTotal tickets: #{@total_jira_tickets}"
@tickets_rank.each do |ticket|
  @list << "#{ticket[:rank]}:#{ticket[:key]}"
end
puts @list.to_s

@previous_key = nil
@total_ranked = 0
@tickets_rank.each_with_index do |ticket, index|
  counter = index + 1
  key = ticket[:key]
  if @previous_key && @is_ticket_key[key]
    jira_rank_issues([key], @previous_key, counter)
    @total_ranked += 1
  end
  @previous_key = key
end

puts"\nTotal ranked: #{@total_ranked}"
