# frozen_string_literal: true

load './lib/common.rb'

@assembla_ticket_to_jira_issue = {}

# assembla_id,jira_key,jira_id
csv_to_array("./z-imported-tickets.csv").each do |ticket|
  @assembla_ticket_to_jira_issue[ticket['assembla_id']] = ticket['jira_key']
end

def update_comment(jira_key, comment_id, body)
  result = nil
  url = "#{URL_JIRA_ISSUES}/#{jira_key}/comment/#{comment_id}"
  headers = JIRA_HEADERS_ADMIN
  payload = {
      body: body
  }.to_json
  begin
    RestClient::Request.execute(method: :put, url: url, payload: payload, headers: headers)
    puts "PUT #{url} body => OK"
    result = true
  rescue RestClient::ExceptionWithResponse => e
    rest_client_exception(e, 'PUT', url, payload)
  rescue => e
    puts "PUT #{url} description => NOK (#{e.message})"
  end
  result
end

@list = []

# jira_key,comment_id,matches,body
csv_to_array('jira-comments-unresolved-links.csv').each do |comment|
  jira_key = comment['jira_key']
  comment_id = comment['comment_id']
  body = comment['body']
  marker1 = '{code:java}'
  marker2 = '{code}'
  if /#{marker1}(.*)#{marker2}/m.match?(body)
    # puts "jira_key='#{jira_key}', comment_id='#{comment_id}' => FOUND"
    body.gsub!(/#{marker1}(.*)#{marker2}/m, '')
  end
  if /#[1-9]\d+/.match(body)
    @list << comment
  else
    # puts "jira_key='#{jira_key}', comment_id='#{comment_id}' => SKIP"
  end
end


puts "Total comments: #{@list.length}"

@count = 0
@list.each do |comment|
  jira_key = comment['jira_key']
  comment_id = comment['comment_id']
  matches = comment['matches']
  result = jira_get_issue_comment(jira_key, comment_id)
  next unless result
  body_before = result['body'].clone
  body = result['body'].clone
  puts "jira_key='#{jira_key}', comment_id='#{comment_id}', matches='#{matches}'"
  matches.split(',').each do |id|
    id = id[1..-1]
    mr = @assembla_ticket_to_jira_issue[id]
    if mr
      body.sub!("##{id}", mr)
    else
      warning("Cannot find jira issue for assembla_id='#{id}'")
    end
  end
  result = update_comment(jira_key, comment_id, body)
  exit unless result
  @count += 1
  comment['body_before'] = body_before
  comment['body_after'] = body
  comment.delete('body')
  write_csv_file_append('jira-comment-links-fix.csv', [comment], @count == 1)
end

