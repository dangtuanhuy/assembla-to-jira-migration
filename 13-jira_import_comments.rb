# frozen_string_literal: true

load './lib/common.rb'
load './lib/users-assembla.rb'

# Assembla comments
comments_assembla_csv = "#{OUTPUT_DIR_ASSEMBLA}/ticket-comments.csv"
@comments_assembla = csv_to_array(comments_assembla_csv)
total_comments = @comments_assembla.length

# Ignore empty comments
@comments_assembla_empty = @comments_assembla.select { |comment| comment['comment'].nil? || comment['comment'].strip.empty? }
@comments_assembla.reject! { |comment| comment['comment'].nil? || comment['comment'].strip.empty? }

puts "Total comments: #{total_comments}"
puts "Empty comments: #{@comments_assembla_empty.length}"
puts "Remaining comments: #{@comments_assembla.length}"
puts "Skip empty comments: #{JIRA_API_SKIP_EMPTY_COMMENTS}"

# Jira tickets
tickets_jira_csv = "#{OUTPUT_DIR_JIRA}/jira-tickets.csv"
@tickets_jira = csv_to_array(tickets_jira_csv)

# Convert assembla_ticket_id to jira_ticket_id and assembla_ticket_number to jira_ticket_key
@assembla_id_to_jira_id = {}
@assembla_id_to_jira_key = {}
@tickets_jira.each do |ticket|
  @assembla_id_to_jira_id[ticket['assembla_ticket_id']] = ticket['jira_ticket_id']
  @assembla_id_to_jira_key[ticket['assembla_ticket_id']] = ticket['jira_ticket_key']
end

# Jira attachments (images)
attachments_jira_csv = "#{OUTPUT_DIR_JIRA}/jira-attachments-download.csv"
@attachments_jira = csv_to_array(attachments_jira_csv)

@list_of_images = {}
@attachments_jira.each do |attachment|
  @list_of_images[attachment['assembla_attachment_id']] = attachment['filename']
end

puts "Attachments: #{@attachments_jira.length}"
puts

# --- Filter by date if TICKET_CREATED_ON is defined --- #
tickets_created_on = get_tickets_created_on

if tickets_created_on
  puts "Filter newer than: #{tickets_created_on}"
  comments_initial = @comments_assembla.length
  # Only want comments which belong to remaining tickets
  @comments_assembla.select! { |item| @assembla_id_to_jira_id[item['ticket_id']] }
  puts "Comments: #{comments_initial} => #{@comments_assembla.length} ∆#{comments_initial - @comments_assembla.length}"
end
puts "Tickets: #{@tickets_jira.length}"

@comments_total = @comments_assembla.length

# POST /rest/api/2/issue/{issueIdOrKey}/comment
def jira_create_comment(issue_id, user_id, comment, counter)
  result = nil
  url = "#{URL_JIRA_ISSUES}/#{issue_id}/comment"
  user_login = @user_id_to_login[user_id]
  user_login.sub!(/@.*$/, '')
  user_email = @user_id_to_email[user_id]
  headers = headers_user_login(user_login, user_email)
  reformatted_body = reformat_markdown(comment['comment'], logins: @list_of_user_logins,
                                                           images: @list_of_images, content_type: 'comments', strikethru: true)
  body = "Created on #{date_time(comment['created_on'])}\n\n#{reformatted_body}"
  if JIRA_SERVER_TYPE == 'cloud'
    author_link = user_login ? "[~#{user_login}]" : "unknown (#{user_id})"
    body = "Author #{author_link} | " + body
  end
  body = "Assembla | #{body}"
  payload = {
    body: body
  }.to_json
  begin
    response = RestClient::Request.execute(method: :post, url: url, payload: payload, headers: headers)
    result = JSON.parse(response.body)
    percentage = ((counter * 100) / @comments_total).round.to_s.rjust(3)
    puts "#{percentage}% [#{counter}|#{@comments_total}] POST #{url} => OK"
  rescue RestClient::ExceptionWithResponse => e
    # TODO: use following helper method for all RestClient calls in other files.
    rest_client_exception(e, 'POST', url)
  rescue => e
    puts "#{percentage}% [#{counter}|#{@comments_total}] POST #{url} => NOK (#{e.message})"
  end
  if result && comment['comment'] != reformatted_body
    id = comment['id']
    ticket_id = comment['ticket_id']
    issue_id = @assembla_id_to_jira_id[ticket_id]
    issue_key = @assembla_id_to_jira_key[ticket_id]
    comment_id = result['id']
    @comments_diffs << {
      jira_comment_id: comment_id,
      jira_ticket_id: issue_id,
      jira_ticket_key: issue_key,
      assembla_comment_id: id,
      assembla_ticket_id: ticket_id,
      before: comment['comment'],
      after: reformatted_body
    }
  end
  result
end

# IMPORTANT: Make sure that the comments are ordered chronologically from first (oldest) to last (newest)
@comments_assembla.sort! { |x, y| x['created_on'] <=> y['created_on'] }

@jira_comments = []

@comments_diffs = []
@comments_skipped = []

@comments_assembla.each_with_index do |comment, index|
  id = comment['id']
  ticket_id = comment['ticket_id']
  user_id = comment['user_id']
  issue_id = @assembla_id_to_jira_id[ticket_id]
  issue_key = @assembla_id_to_jira_key[ticket_id]
  user_login = @user_id_to_login[user_id]
  body = comment['comment']
  if JIRA_API_SKIP_EMPTY_COMMENTS && (body.nil? || body.length.zero?)
    @comments_skipped << comment
    next
  end
  result = jira_create_comment(issue_id, user_id, comment, index + 1)
  next unless result
  comment_id = result['id']
  @jira_comments << {
    jira_comment_id: comment_id,
    jira_ticket_id: issue_id,
    jira_ticket_key: issue_key,
    assembla_comment_id: id,
    assembla_ticket_id: ticket_id,
    user_login: user_login,
    body: body
  }
end

puts "Total all: #{@comments_total}"
comments_jira_csv = "#{OUTPUT_DIR_JIRA}/jira-comments.csv"
write_csv_file(comments_jira_csv, @jira_comments)

comments_diffs_jira_csv = "#{OUTPUT_DIR_JIRA}/jira-comments-diffs.csv"
write_csv_file(comments_diffs_jira_csv, @comments_diffs)

if JIRA_API_SKIP_EMPTY_COMMENTS && @comments_skipped.length
  puts "Comments skipped: #{@comments_skipped.length}"
  comments_skipped_jira_csv = "#{OUTPUT_DIR_JIRA}/jira-comments-skipped.csv"
  write_csv_file(comments_skipped_jira_csv, @comments_skipped)
end
