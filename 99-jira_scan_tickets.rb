# frozen_string_literal: true

load './lib/common.rb'

# re = %r{ https?://.*\.assembla\.com/spaces/(europeana\-.*)/tickets/ }
re = %r{https?://.*\.assembla\.com/spaces/(europeana\-.*)/tickets/(\d+)}

@tickets_jira = csv_to_array("#{OUTPUT_DIR_JIRA}/jira-tickets.csv")
@comments_jira = csv_to_array("#{OUTPUT_DIR_JIRA}/jira-comments.csv")

@ticket_a_id_to_a_nr = {}
@ticket_j_id_to_j_key = {}
@ticket_a_nr_to_j_key = {}
@tickets_jira.each do |ticket|
  @ticket_a_id_to_a_nr[ticket['assembla_ticket_id']] = ticket['assembla_ticket_number']
  @ticket_j_id_to_j_key[ticket['jira_ticket_id']] = ticket['jira_ticket_key']
  @ticket_a_nr_to_j_key[ticket['assembla_ticket_number']] = ticket['jira_ticket_key']
end

list = []
spaces = []

# jira_ticket_id,jira_ticket_key,assembla_ticket_id,assembla_ticket_number
@tickets_jira.each do |item|
  content = item['description']
  lines = content.split("\n")
  # Ignore the first line
  lines.shift
  lines.each do |line|
    if re.match(line)
      spaces << $1 unless spaces.include?($1)
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
      spaces << $1 unless spaces.include?($1)
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
