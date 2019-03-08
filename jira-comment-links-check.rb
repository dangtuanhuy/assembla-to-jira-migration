# frozen_string_literal: true

load './lib/common.rb'

# This script scan the assembla ticket comments for ticket links in the description text:
#
# [[ticket:n]] or #n where n = [1-9]\d+
#

# id,comment,user_id,created_on,updated_at,ticket_changes,user_name,user_avatar_url,ticket_id,ticket_number

assembla_id_to_number = {}
csv_to_array("#{OUTPUT_DIR_ASSEMBLA}/ticket-comments.csv").each do |comment|
  assembla_id_to_number[comment['id']] = comment['ticket_number']
end

assembla_comment_id_to_jira_comment_id = {}
jira_comments = csv_to_array("#{OUTPUT_DIR_JIRA}/jira-comments.csv").each do |comment|
  assembla_comment_id_to_jira_comment_id[comment['assembla_comment_id']] = comment['jira_comment_id']
end


assembla_id_to_jira_key = {}
jira_key_to_assembla_id = {}
csv_to_array('./z-imported-tickets.csv').each do |issue|
  assembla_id_to_jira_key[issue['assembla_id']] = issue['jira_key']
  jira_key_to_assembla_id[issue['jira_key']] = issue['assembla_id']
end

list = []
jira_keys = []
csv_to_array("#{OUTPUT_DIR_ASSEMBLA}/ticket-comments.csv").each do |comment|
  comment_id = comment['id']
  id = comment['ticket_id']
  number = comment['ticket_number']
  c = comment['comment']
  next if c.nil? or c.length.zero?
  jira_key = assembla_id_to_jira_key[number]
  jira_keys << jira_key unless jira_keys.include?(jira_key)
  matches = []
  c.scan(/#[1-9]\d*/).each {|n| matches << n}
  if matches.length.nonzero?
    list << {id: id, number: number, jira_key: jira_key, comment_id: comment_id, matches: matches}
  end
end

@total_found = 0
puts "Jira issue: #{jira_keys.length}"
if jira_keys.length.nonzero?
  jira_keys.sort{ |a,b| a[3..-1].to_i <=> b[3..-1].to_i }.each do |key|
    next if key[3..-1].to_i < 8100
    comments = jira_get_issue_comments(key)
    exit unless comments
    comments.each do |comment|
      id = comment['id']
      body = comment['body']
      next if body.nil? || body.length.zero?
      unless /^Assembla \| Author /.match?(body)
        warning("key=#{key}, comment_id='#{id}' is not an Assembla comment => skip")
        next
      end
      body = body.lines[2..-1].join("\n")
      matches = []
      body.scan(/#[1-9]\d*/).each { |n| matches << n }
      next unless matches.length.nonzero?
      found = {}
      found['jira_key'] = key
      found['comment_id'] = id
      found['matches'] = matches.join(',')
      found['body'] = body
      @total_found += 1
      write_csv_file_append('jira-comments-unresolved-links.csv', [found], false && @total_found == 1)
    end
  end
end

