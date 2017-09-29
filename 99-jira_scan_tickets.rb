# frozen_string_literal: true

load './lib/common.rb'

@projects = []

@projects_csv = csv_to_array("#{output_dir_jira(JIRA_API_PROJECT_NAME)}/jira-projects.csv")

JIRA_API_SPACE_TO_PROJECT.split(',').each do |item|
  space, key = item.split(':')
  goodbye("Missing space, item=#{item}, JIRA_API_SPACE_TO_PROJECT=#{JIRA_API_SPACE_TO_PROJECT}") unless space
  goodbye("Missing key, item=#{item}, JIRA_API_SPACE_TO_PROJECT=#{JIRA_API_SPACE_TO_PROJECT}") unless key

  project = @projects_csv.find { |project| project['key'] == key }
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
    jira_comment_id ='0'
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

# => /browse/[:jira-ticket-key]?focusedCommentId=[:jira-comment-id]&page=com.atlassian.jira.plugin.system.issuetabpanels:comment-tabpanel#comment-[:jira-comment-id]

@list = []
@spaces = {}

def collect_list(type, item)
  goodbye("Collect list: invalid type=#{type}, must be 'ticket' or 'comment'") unless %w(ticket comment).include?(type)

  content = item[type == 'ticket' ? 'description' : 'body']
  assembla_ticket_nr = type == 'ticket' ? item['assembla_ticket_number'] : @ticket_a_id_to_a_nr[item['assembla_ticket_id']]
  jira_ticket_key = item['jira_ticket_key']

  # Split content into lines, and ignore the first line.
  lines = split_into_lines(content)
  lines.shift
  lines.each do |line|
    next unless line.strip.length.positive?
    line_after = line
                 .gsub(@re_comment) { |match| "COMMENT[space='#{$1}', link='#{$2}', comment='#{$3}']"}
                 .gsub(@re_ticket) { |match| "TICKET[space='#{$1}', link='#{$2}']"}

    if line_after != line
      puts "BEFORE: '#{line}'"
      puts "AFTER : '#{line_after}'"
    end
    # space = $1
    #
    # assembla_link_ticket_nr = $2
    # # jira_link_ticket_key => calculated from link_ticket_a_nr_to_j_key(assembla_link_ticket_nr)
    #
    # assembla_link_comment_id = $3
    # # jira_link_comment_id => calculated from link_comment_a_id_to_j_id(assembla_link_comment_id)
    #
    # match = $&
    # replace_with = ''
    #
    # # IMPORTANT: Following must come after previous three statements (to preserve values $2, $3 and $&)
    # project = @project_by_space[space]
    #
    # @spaces[space] = 0 unless @spaces[space]
    # @spaces[space] += 1
    #
    # is_link_comment = !assembla_link_comment_id.nil?
    #
    # assembla_comment_id = ''
    # assembla_comment_id = type == 'comment' ? item['assembla_comment_id'] : ''
    # jira_comment_id = type == 'comment' ? item['jira_comment_id'] : ''
    # jira_link_ticket_key = ''
    # assembla_link_comment_id ||= ''
    # jira_link_comment_id = ''
    #
    # # TICKET:  jira_ticket_id,jira_ticket_key,assembla_ticket_id,assembla_ticket_number
    # # COMMENT: jira_comment_id,jira_ticket_id,jira_ticket_key,assembla_comment_id,assembla_ticket_id
    #
    # # type                         TICKET                 COMMENT
    # #                              ======                 =======
    # # is_link_comment(True/False)  F(ticket)  T(comment)  F(ticket) T(comment)
    # #                              ---------  ----------  --------- ----------
    # # assembla_ticket_nr           x          x           x         x
    # # jira_ticket_key              x          x           x         x
    # # assembla_link_ticket_nr      x          x           x         x
    # # jira_link_ticket_key         x          x           x         x (calculated)
    # #
    # # assembla_comment_id          o          o           x         x
    # # jira_comment_id              o          o           x         x
    # # assembla_link_comment_id     o          x           o         x
    # # jira_link_comment_id         o          x           o         x (calculated)
    #
    # if project
    #   jira_link_ticket_key = link_ticket_a_nr_to_j_key(space, assembla_link_ticket_nr)
    #   if is_link_comment
    #     jira_link_comment_id = link_comment_a_id_to_j_id(space, assembla_link_comment_id)
    #     replace_with = "#{JIRA_API_BASE}/#{JIRA_API_BROWSE_COMMENT.sub('[:jira-ticket-key]', jira_link_ticket_key).sub('[:jira-comment-id]', jira_link_comment_id)}"
    #   else
    #     replace_with = "#{JIRA_API_BASE}/#{JIRA_API_BROWSE_ISSUE.sub('[:jira-ticket-key]', jira_link_ticket_key)}"
    #   end
    # end
    #
    # @list << {
    #   result: project ? 'OK' : 'SKIP',
    #   replace: replace_with == '' ? 'NO' : 'YES',
    #   space: space,
    #   type: type,
    #   is_link_comment: is_link_comment,
    #   assembla_ticket_nr: assembla_ticket_nr,
    #   jira_ticket_key: jira_ticket_key,
    #   assembla_comment_id: assembla_comment_id,
    #   jira_comment_id: jira_comment_id,
    #   assembla_link_ticket_nr: assembla_link_ticket_nr,
    #   jira_link_ticket_key: jira_link_ticket_key,
    #   assembla_link_comment_id: assembla_link_comment_id,
    #   jira_link_comment_id: jira_link_comment_id,
    #   match: match,
    #   replace_with: replace_with,
    #   line: line
    # }
  end
end

@tickets_jira.each do |item|
  collect_list('ticket', item)
end

@comments_jira.each do |item|
  collect_list('comment', item)
end

puts "\nTotal spaces: #{@spaces.length}"
@spaces.each do |k, v|
  puts "* #{k} (#{v}) => #{@projects.find { |project| project[:space] == k } ? 'OK' : 'SKIP'}"
end
puts

write_csv_file("#{OUTPUT_DIR_JIRA}/jira-links-external.csv", @list)

@projects.each do |project|
  space = project[:space]
  rows = @list.select { |row| row[:space] == space }
  puts "\n#{space} => #{rows.length}"
  rows.each do |row|
    puts "#{row[:type]} '#{row[:match]}' => '#{row[:replace_with]}'"
  end
end
