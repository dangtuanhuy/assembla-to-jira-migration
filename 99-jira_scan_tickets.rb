# frozen_string_literal: true

load './lib/common.rb'

spaces = {}
projects = []

# Tickets:
# https?://.*?\.assembla\.com/spaces/(.*?)/tickets/(\d+)
# https?://.*?\.assembla\.com/spaces/(.*?)/tickets/(\d+)-summary
# https?://.*?\.assembla\.com/spaces/(.*?)/tickets/(\d+)-summary/details#?
# https?://.*?\.assembla\.com/spaces/(.*?)/tickets/(\d+)-summary/details\?tab=activity
# https?://.*?\.assembla\.com/spaces/(.*?)/tickets/(\d+)-summary/activity/ticket:
#
# Comments:
# https?://.*?\.assembla\.com/spaces/(.*?)/tickets/(\d+)/details?comment=(\d+)
# https?://.*?\.assembla\.com/spaces/(.*?)/tickets/(\d+)-summary?comment=(\d+)
# https?://.*?\.assembla\.com/spaces/(.*?)/tickets/(\d+)-summary?comment=(\d+)#comment:(\d+)

re_ticket = %r{https?://.*?\.assembla\.com/spaces/(.*?)/tickets/(\d+)(\-.*)?(\?.*\b)?}

re_comment = %r{https?://.*?\.assembla\.com/spaces/(.*?)/tickets/(\d+)(/details|\-.*?)\?comment=(\d+)(#comment:\d+)?}

projects_csv = csv_to_array("#{output_dir_jira(JIRA_API_PROJECT_NAME)}/jira-projects.csv")

JIRA_API_SPACE_TO_PROJECT.split(',').each do |item|
  space, key = item.split(':')
  goodbye("Missing space, item=#{item}, JIRA_API_SPACE_TO_PROJECT=#{JIRA_API_SPACE_TO_PROJECT}") unless space
  goodbye("Missing key, item=#{item}, JIRA_API_SPACE_TO_PROJECT=#{JIRA_API_SPACE_TO_PROJECT}") unless key

  project = projects_csv.find { |project| project['key'] == key }
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

  projects << {
    space: space,
    key: key,
    name: project_name,
    output_dir: output_dir,
    ticket_a_nr_to_j_key: ticket_a_nr_to_j_key,
    comment_a_id_to_j_id: comment_a_id_to_j_id
  }
end

@project_by_space = {}
projects.each do |project|
  project_by_space[project['space']] = project
end

@tickets_jira = csv_to_array("#{OUTPUT_DIR_JIRA}/jira-tickets.csv")
@comments_jira = csv_to_array("#{OUTPUT_DIR_JIRA}/jira-comments.csv")

@ticket_a_id_to_a_nr = {}
@ticket_a_nr_to_j_key = {}
@tickets_jira.each do |ticket|
  @ticket_a_id_to_a_nr[ticket['assembla_ticket_id']] = ticket['assembla_ticket_number']
  @ticket_a_nr_to_j_key[ticket['assembla_ticket_number']] = ticket['jira_ticket_key']
end

# Convert the Assembla ticket number to the Jira issue key
def link_ticket_a_nr_to_j_key(space, assembla_ticket_nr)
  project = @project_by_space[space]
  goodbye("Cannot get project, space='#{space}'") unless project
  jira_issue_key = project[:ticket_a_nr_to_j_key][assembla_ticket_nr]
  goodbye("Cannot get jira_issue_key, space='#{space}', assembla_ticket_nr='#{assembla_ticket_nr}'") unless jira_issue_key
  jira_issue_key
end

# Convert the Assembla comment id to the Jira comment id
def link_comment_a_id_to_j_id(space, assembla_comment_id)
  return nil unless assembla_comment_id
  project = @project_by_space[space]
  goodbye("Cannot get project, space='#{space}'") unless project
  jira_comment_id = project[:comment_a_id_to_j_id][assembla_comment_id]
  goodbye("Cannot get jira_comment_id, space='#{space}', assembla_comment_id='#{assembla_comment_id}'") unless jira_comment_id
  jira_comment_id
end

list = []

# jira_ticket_id,jira_ticket_key,assembla_ticket_id,assembla_ticket_number
@tickets_jira.each do |item|
  content = item['description']
  lines = split_into_lines(content)
  # Ignore the first line
  lines.shift
  lines.each do |line|
    found = false
    # next unless line.strip.length.positive? && re_ticket.match(line)
    next unless line.strip.length.positive? && (re_ticket_match(line) || re_comment_match(line))
    space = $1
    link_assembla_ticket_nr = $2
    link_assembla_comment_id = $3
    match = $&
    spaces[space] = 0 unless spaces[space]
    spaces[space] += 1
    list << {
      space: space,
      type: 'ticket',
      assembla_ticket_number: item['assembla_ticket_number'],
      jira_ticket_key: item['jira_ticket_key'],
      assembla_comment_id: '',
      jira_comment_id: '',
      link_assembla_ticket_number: link_assembla_ticket_nr,
      link_jira_ticket_key: link_ticket_a_nr_to_j_key(space, link_assembla_ticket_nr),
      link_assembla_comment_id: link_assembla_comment_id,
      link_jira_comment_id: link_comment_a_id_to_j_id(space, link_assembla_comment_id),
      match: match,
      line: line
    }
  end
end

# jira_comment_id,jira_ticket_id,jira_ticket_key,assembla_comment_id,assembla_ticket_id
@comments_jira.each do |item|
  content = item['body']
  lines = split_into_lines(content)
  # Ignore the first line
  lines.shift
  lines.each do |line|
    # next unless line.strip.length.positive? && re_ticket.match(line)
    next unless line.strip.length.positive?
    if re_comment.match(line)
    space = $1
    ticket_nr = $2
    match = $&
    list << {
      space: space,
      type: 'comment',
      assembla_ticket_number: @ticket_a_id_to_a_nr[item['assembla_ticket_id']],
      jira_ticket_key: item['jira_ticket_key'],
      assembla_comment_id: item['assembla_comment_id'],
      jira_comment_id: item['jira_comment_id'],
      link_assembla_ticket_number: ticket_nr,
      link_jira_ticket_key: @ticket_a_nr_to_j_key[ticket_nr],
      match: match,
      line: line
    }
    elsif re_ticket.match(line)
    end
  end
end

puts "\nTotal spaces: #{spaces.length}"
spaces.each do |k, v|
  puts "* #{k} (#{v}) => #{projects.find { |project| project[:space] == k } ? 'OK' : 'SKIP'}"
end
puts

write_csv_file("#{OUTPUT_DIR_JIRA}/jira-links-external.csv", list)

# http://localhost:8080/browse/EC-4820?focusedCommentId=30334&page=com.atlassian.jira.plugin.system.issuetabpanels:comment-tabpanel#comment-30334

projects.each do |project|
  space = project[:space]
  rows = list.select { |row| row[:space] == space }
  puts "\n#{space} => #{rows.length}"
  rows.each do |row|
    puts "#{row[:type]} '#{row[:match]}'"
  end
end
