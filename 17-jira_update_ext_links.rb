# frozen_string_literal: true

load './lib/common.rb'
load './lib/users-assembla.rb'

@projects_csv = csv_to_array("#{output_dir_jira(JIRA_API_PROJECT_NAME)}/jira-projects.csv")

@projects = []

JIRA_API_SPACE_TO_PROJECT.split(',').each do |item|
  space, key = item.split(':')
  goodbye("Missing space, item=#{item}, JIRA_API_SPACE_TO_PROJECT=#{JIRA_API_SPACE_TO_PROJECT}") unless space
  goodbye("Missing key, item=#{item}, JIRA_API_SPACE_TO_PROJECT=#{JIRA_API_SPACE_TO_PROJECT}") unless key

  project = @projects_csv.detect { |p| p['key'] == key }
  goodbye("Cannot find project with key=#{key}, item=#{item}, JIRA_API_SPACE_TO_PROJECT=#{JIRA_API_SPACE_TO_PROJECT}") unless project
  project_name = project['name']

  output_dir = output_dir_jira(project_name)

  tickets = csv_to_array("#{output_dir}/jira-tickets.csv")
  comments = csv_to_array("#{output_dir}/jira-comments.csv")

  ticket_a_nr_to_j_key = {}
  tickets.each do |ticket|
    ticket_a_nr_to_j_key[ticket['assembla_ticket_number']] = ticket['jira_ticket_key']
  end

  comment_a_id_to_j_id = {}
  comments.each do |comment|
    comment_a_id_to_j_id[comment['assembla_comment_id']] = comment['jira_comment_id']
  end

  @projects << {
    space: space,
    key: key,
    name: project_name,
    output_dir: output_dir,
    ticket_a_nr_to_j_key: ticket_a_nr_to_j_key,
    comment_a_id_to_j_id: comment_a_id_to_j_id
  }
end

@project_by_space = {}
@projects.each do |project|
  @project_by_space[project[:space]] = project
end

@tickets_jira = csv_to_array("#{OUTPUT_DIR_JIRA}/jira-tickets.csv")

@ticket_a_id_to_a_nr = {}
@ticket_a_nr_to_j_key = {}
@ticket_j_key_to_j_reporter = {}
@tickets_jira.each do |ticket|
  @ticket_a_id_to_a_nr[ticket['assembla_ticket_id']] = ticket['assembla_ticket_number']
  @ticket_a_nr_to_j_key[ticket['assembla_ticket_number']] = ticket['jira_ticket_key']
  @ticket_j_key_to_j_reporter[ticket['jira_ticket_key']] = ticket['reporter_name']
end

@comments_jira = csv_to_array("#{OUTPUT_DIR_JIRA}/jira-comments.csv")

@comment_j_key_to_j_login = {}
@comments_jira.each do |comment|
  @comment_j_key_to_j_login[comment['jira_ticket_key']] = comment['user_login']
end

def jira_update_issue_description(issue_key, description)
  result = nil
  user_login = @ticket_j_key_to_j_reporter[issue_key]
  user_login.sub!(/@.*$/,'')
  user_email = @user_login_to_email[user_login]
  headers = if JIRA_SERVER_TYPE == 'hosted'
              headers_user_login(user_login, user_email)
            else
              JIRA_HEADERS_CLOUD
            end
  url = "#{URL_JIRA_ISSUES}/#{issue_key}"
  payload = {
    update: {},
    fields: {
      description: description
    }
  }.to_json
  begin
    RestClient::Request.execute(method: :put, url: url, payload: payload, headers: headers)
    puts "PUT #{url} description => OK"
    result = true
  rescue RestClient::ExceptionWithResponse => e
    rest_client_exception(e, 'PUT', url, payload)
  rescue => e
    puts "PUT #{url} description => NOK (#{e.message})"
  end
  result
end

def jira_update_comment_body(issue_key, comment_id, body)
  result = nil
  user_login = @comment_j_key_to_j_login[issue_key]
  user_login.sub!(/@.*$/,'')
  user_email = @user_login_to_email[user_login]
  headers = if JIRA_SERVER_TYPE == 'hosted'
              headers_user_login(user_login, user_email)
            else
              JIRA_HEADERS_CLOUD
            end
  url = "#{URL_JIRA_ISSUES}/#{issue_key}/comment/#{comment_id}"
  payload = {
    body: body
  }.to_json
  begin
    RestClient::Request.execute(method: :put, url: url, payload: payload, headers: headers)
    puts "PUT #{url} description => OK"
    result = true
  rescue RestClient::ExceptionWithResponse => e
    rest_client_exception(e, 'PUT', url, payload)
  rescue => e
    puts "PUT #{url} description => NOK (#{e.message})"
  end
  result
end

# Convert the Assembla ticket number to the Jira issue key
def link_ticket_a_nr_to_j_key(space, assembla_ticket_nr)
  project = @project_by_space[space]
  goodbye("Cannot get project, space='#{space}'") unless project
  jira_issue_key = project[:ticket_a_nr_to_j_key][assembla_ticket_nr]
  unless jira_issue_key
    puts("Cannot get jira_issue_key, space='#{space}', assembla_ticket_nr='#{assembla_ticket_nr}'")
    jira_issue_key = '0'
  end
  jira_issue_key
end

# Convert the Assembla comment id to the Jira comment id
def link_comment_a_id_to_j_id(space, assembla_comment_id)
  return nil unless assembla_comment_id
  project = @project_by_space[space]
  goodbye("Cannot get project, space='#{space}'") unless project
  jira_comment_id = project[:comment_a_id_to_j_id][assembla_comment_id]
  unless jira_comment_id
    puts("Cannot get jira_comment_id, space='#{space}', assembla_comment_id='#{assembla_comment_id}'")
    jira_comment_id = '0'
  end
  jira_comment_id
end

# Tickets:
# https?://.*?\.assembla\.com/spaces/(.*?)/tickets/(\d+)
# https?://.*?\.assembla\.com/spaces/(.*?)/tickets/(\d+)-summary
# https?://.*?\.assembla\.com/spaces/(.*?)/tickets/(\d+)-summary/details#?
# https?://.*?\.assembla\.com/spaces/(.*?)/tickets/(\d+)-summary/details\?tab=activity
# https?://.*?\.assembla\.com/spaces/(.*?)/tickets/(\d+)-summary/activity/ticket:

# @re_ticket = %r{https?://.*?\.assembla\.com/spaces/(.*?)/tickets/(\d+)(?:\-.*)?(?:\?.*\b)?}
@re_ticket = %r{https?://.*?\.assembla\.com/spaces/(.*?)/tickets/(\d+)(?:\-[^)\]]+)?(?:\?.*\b)?}

# => /browse/[:jira-ticket-key]

# Comments:
# https?://.*?\.assembla\.com/spaces/(.*?)/tickets/(\d+)/details?comment=(\d+)
# https?://.*?\.assembla\.com/spaces/(.*?)/tickets/(\d+)-summary?comment=(\d+)
# https?://.*?\.assembla\.com/spaces/(.*?)/tickets/(\d+)-summary?comment=(\d+)#comment:(\d+)

@re_comment = %r{https?://.*?\.assembla\.com/spaces/(.*?)/tickets/(\d+).*?\?comment=(\d+)(?:#comment:\d+)?}

# => /browse/[:jira-ticket-key]?focusedCommentId=[:jira-comment-id]&page=com.atlassian.jira.plugin.system
# .issuetabpanels:comment-tabpanel#comment-[:jira-comment-id]

@list_external_all = []
@list_external_updated = []
@spaces = {}

def handle_match(match, type, item, line, assembla_ticket_nr, jira_ticket_key, space, assembla_link_ticket_nr, assembla_link_comment_id)
  # jira_link_ticket_key => calculated from link_ticket_a_nr_to_j_key(assembla_link_ticket_nr)
  # jira_link_comment_id => calculated from link_comment_a_id_to_j_id(assembla_link_comment_id)

  replace_with = nil

  project = @project_by_space[space]

  @spaces[space] = 0 unless @spaces[space]
  @spaces[space] += 1

  is_link_comment = !assembla_link_comment_id.nil?

  assembla_comment_id = type == 'comment' ? item['assembla_comment_id'] : ''
  jira_comment_id = type == 'comment' ? item['jira_comment_id'] : ''
  jira_link_ticket_key = ''
  assembla_link_comment_id ||= ''
  jira_link_comment_id = ''

  # TICKET:  jira_ticket_id,jira_ticket_key,assembla_ticket_id,assembla_ticket_number
  # COMMENT: jira_comment_id,jira_ticket_id,jira_ticket_key,assembla_comment_id,assembla_ticket_id

  # type                         TICKET                 COMMENT
  #                              ======                 =======
  # is_link_comment(True/False)  F(ticket)  T(comment)  F(ticket) T(comment)
  #                              ---------  ----------  --------- ----------
  # assembla_ticket_nr           x          x           x         x
  # jira_ticket_key              x          x           x         x
  # assembla_link_ticket_nr      x          x           x         x
  # jira_link_ticket_key         x          x           x         x (calculated)
  #
  # assembla_comment_id          o          o           x         x
  # jira_comment_id              o          o           x         x
  # assembla_link_comment_id     o          x           o         x
  # jira_link_comment_id         o          x           o         x (calculated)

  if project
    jira_link_ticket_key = link_ticket_a_nr_to_j_key(space, assembla_link_ticket_nr)
    url = JIRA_API_BROWSE_ISSUE.sub('[:jira-ticket-key]', jira_link_ticket_key)
    if is_link_comment
      jira_link_comment_id = link_comment_a_id_to_j_id(space, assembla_link_comment_id)
      if jira_link_comment_id.to_i.positive?
        url = JIRA_API_BROWSE_COMMENT.sub('[:jira-ticket-key]', jira_link_ticket_key).sub('[:jira-comment-id]', jira_link_comment_id)
      end
    end
    replace_with = "#{JIRA_API_BASE}/#{url}"
  end

  line_after = replace_with.nil? ? '' : line.sub(match, replace_with)

  @list_external_all << {
    result: project ? 'OK' : 'SKIP',
    replace: replace_with.nil? ? 'NO' : 'YES',
    space: space,
    type: type,
    is_link_comment: is_link_comment,
    assembla_ticket_nr: assembla_ticket_nr,
    jira_ticket_key: jira_ticket_key,
    assembla_comment_id: assembla_comment_id,
    jira_comment_id: jira_comment_id,
    assembla_link_ticket_nr: assembla_link_ticket_nr,
    jira_link_ticket_key: jira_link_ticket_key,
    assembla_link_comment_id: assembla_link_comment_id,
    jira_link_comment_id: jira_link_comment_id,
    match: match,
    replace_with: replace_with.nil? ? '' : replace_with,
    line_before: line,
    line_after: line_after
  }

  replace_with.nil? ? match : replace_with
end

def collect_list_external_all(type, item)
  goodbye("Collect list_external_all: invalid type=#{type}, must be 'ticket' or 'comment'") unless %w(ticket comment).include?(type)

  if type == 'ticket'
    content = item['description']
    assembla_ticket_nr = item['assembla_ticket_number']
    jira_ticket_key = item['jira_ticket_key']
    assembla_comment_id = ''
    jira_comment_id = ''
  else
    content = item['body']
    assembla_ticket_nr = @ticket_a_id_to_a_nr[item['assembla_ticket_id']]
    jira_ticket_key = item['jira_ticket_key']
    assembla_comment_id = item['assembla_comment_id']
    jira_comment_id = item['jira_comment_id']
  end

  # Split content into lines, and ignore the first line.
  lines = split_into_lines(content)
  first_line = lines.shift
  lines_before = lines
  lines_after = []
  lines_changed = false
  lines.each do |line|
    line_before = line
    line_after = line
    if line.strip.length.positive?
      blk = ->(match) { handle_match(match, type, item, line, assembla_ticket_nr, jira_ticket_key, $1, $2, $3) }
      # IMPORTANT: @re_comment MUST precede @re_ticket
      line_after = line.
                   gsub(@re_comment, &blk).
                   gsub(@re_ticket, &blk)
    end
    lines_after << line_after
    if line_before != line_after
      # puts "'#{line_before}' => '#{line_after}'"
      lines_changed = true
    end
  end
  if lines_changed
    # puts "BEFORE:\n'#{lines_before.join("\n")}'\nAFTER:\n'#{lines.join("\n")}'"
    @list_external_updated << {
      type: type,
      assembla_ticket_nr: assembla_ticket_nr,
      jira_ticket_key: jira_ticket_key,
      assembla_comment_id: assembla_comment_id,
      jira_comment_id: jira_comment_id,
      before: "#{first_line}\n#{lines_before.join("\n")}",
      after: "#{first_line}\n#{lines_after.join("\n")}"
    }
  end
end

@tickets_jira.each do |item|
  collect_list_external_all('ticket', item)
end

@comments_jira.each do |item|
  collect_list_external_all('comment', item)
end

puts "\nTotal spaces: #{@spaces.length}"
@spaces.each do |k, v|
  puts "* #{k} (#{v}) => #{@projects.detect { |project| project[:space] == k } ? 'OK' : 'SKIP'}"
end
puts

write_csv_file("#{OUTPUT_DIR_JIRA}/jira-links-external-all.csv", @list_external_all)
write_csv_file("#{OUTPUT_DIR_JIRA}/jira-links-external-updated.csv", @list_external_updated)

@projects.each do |project|
  space = project[:space]
  rows = @list_external_all.select { |row| row[:space] == space }
  puts "\n#{space} => #{rows.length}"
  rows.each do |row|
    puts "#{row[:type]} '#{row[:match]}' => '#{row[:replace_with]}'"
  end
end

# Go to work!

@all_external_tickets = @list_external_updated.select { |x| x[:type] == 'ticket' }
@all_external_comments = @list_external_updated.select { |x| x[:type] == 'comment' }

puts "\nTICKETS:"
@all_external_tickets.sort { |x, y| x[:jira_ticket_key] <=> y[:jira_ticket_key] }.each do |ticket|
  issue_key = ticket[:jira_ticket_key]
  description = ticket[:after]
  # puts "\nissue_key='#{issue_key}'"
  # puts "description='#{description}'"
  jira_update_issue_description(issue_key, description)
end

puts "\nComments:"
@all_external_comments.sort { |x, y| x[:jira_comment_id] <=> y[:jira_comment_id] }.each do |comment|
  issue_key = comment[:jira_ticket_key]
  comment_id = comment[:jira_comment_id]
  body = comment[:after]
  # puts "\nissue_key='#{issue_key}' comment_id='#{comment_id}'"
  # puts "body='#{body}'"
  jira_update_comment_body(issue_key, comment_id, body)
end
