# frozen_string_literal: true

load './lib/common.rb'

projects = []

JIRA_API_SPACE_TO_PROJECT.split(',').each do |item|
  space, key = item.split(':')
  goodbye("Missing space, item=#{item}, JIRA_API_SPACE_TO_PROJECT=#{JIRA_API_SPACE_TO_PROJECT}") unless space
  goodbye("Missing key, item=#{item}, JIRA_API_SPACE_TO_PROJECT=#{JIRA_API_SPACE_TO_PROJECT}") unless key

  project = jira_get_project_by_key(key)
  goodbye("Cannot find project with key=#{key}, item=#{item}, JIRA_API_SPACE_TO_PROJECT=#{JIRA_API_SPACE_TO_PROJECT}") unless project
  project_name = project['name']
  normalized_name = normalize_name(project_name)

  output_dir = "#{OUTPUT_DIR}/jira/#{normalized_name}"

  tickets = csv_to_array("#{output_dir}/jira-tickets.csv")
  comments = csv_to_array("#{output_dir}/jira-comments.csv")

  ticket_a_id_to_a_nr = {}
  ticket_a_nr_to_j_key = {}
  tickets.each do |ticket|
    ticket_a_id_to_a_nr[ticket['assembla_ticket_id']] = ticket['assembla_ticket_number']
    ticket_a_nr_to_j_key[ticket['assembla_ticket_number']] = ticket['jira_ticket_key']
  end

  projects << {
    space: space,
    key: key,
    name: project_name,
    output_dir: output_dir,
    tickets: tickets,
    comments: comments,
    ticket_a_id_to_a_nr: ticket_a_id_to_a_nr,
    ticket_a_nr_to_j_key: ticket_a_nr_to_j_key
  }
end

project_by_space = {}
project.each do |project|
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

list = []

# http://localhost:8080/browse/EC-4820?focusedCommentId=30334&page=com.atlassian.jira.plugin.system.issuetabpanels:comment-tabpanel#comment-30334

# jira_ticket_id,jira_ticket_key,assembla_ticket_id,assembla_ticket_number
@tickets_jira.each do |item|
  content = item['description']
  lines = content.split("\n")
  # Ignore the first line
  lines.shift
  lines.each do |line|
    if re.match(line)
      list << {
        space: $1,
        type: 'ticket',
        assembla_ticket_number: item['assembla_ticket_number'],
        jira_ticket_key: item['jira_ticket_key'],
        assembla_comment_id: '',
        jira_comment_id: '',
        link_assembla_ticket_number: $2,
        link_jira_ticket_key: @ticket_a_nr_to_j_key[$2],
        match: $&,
        line: line
      }
    end
  end
end

# jira_comment_id,jira_ticket_id,jira_ticket_key,assembla_comment_id,assembla_ticket_id
@comments_jira.each do |item|
  content = item['body']
  lines = content.split("\n")
  # Ignore the first line
  lines.shift
  lines.each do |line|
    if re.match(line)
      list << {
        space: $1,
        type: 'comment',
        assembla_ticket_number: @ticket_a_id_to_a_nr[item['assembla_ticket_id']],
        jira_ticket_key: item['jira_ticket_key'],
        assembla_comment_id: item['assembla_comment_id'],
        jira_comment_id: item['jira_comment_id'],
        ink_assembla_ticket_number: $2,
        link_jira_ticket_key: @ticket_a_nr_to_j_key[$2],
        match: $&,
        line: line
      }
    end
  end
end

write_csv_file("#{OUTPUT_DIR_JIRA}/jira-links-external.csv", list)
