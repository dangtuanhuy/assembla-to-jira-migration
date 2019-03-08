# frozen_string_literal: true

load './lib/common.rb'

# This script scan the assembla tickets for ticket links in the description text:
#
# [[ticket:n]] or #n where n = [1-9]\d+
#

assembla_tickets = csv_to_array("#{OUTPUT_DIR_ASSEMBLA}/tickets.csv")
puts "Total assembla tickets: #{assembla_tickets.length}"

jira_issues = csv_to_array('./z-imported-tickets.csv')
puts "Total jira issues: #{jira_issues.length}"

assembla_id_to_jira_key = {}
jira_key_to_assembla_id = {}
jira_issues.each do |issue|
  assembla_id_to_jira_key[issue['assembla_id']] = issue['jira_key']
  jira_key_to_assembla_id[issue['jira_key']] = issue['assembla_id']
end

list = []
assembla_tickets.each do |ticket|
  id = ticket['id']
  number = ticket['number']
  description = ticket['description']
  jira_key = assembla_id_to_jira_key[number]
  next if description.nil? || description.length.zero?
  matches = []
  description.scan(/#[1-9]\d*/).each { |n| matches << n }
  if matches.length.nonzero?
    list << { id: id, number: number, jira_key: jira_key, matches: matches }
  end
end

list.each do |l|
  id = l[:id]
  number = l[:number]
  jira_key = l[:jira_key]
  matches = l[:matches]
  mlist = []
  matches.each do |n|
    mlist << "#{n}:#{assembla_id_to_jira_key[n[1..-1]]}"
  end
  puts "#{id} #{number} #{jira_key}: #{mlist.join(', ')}"
end

list.each do |l|
  id = l[:id]
  number = l[:number]
  jira_key = l[:jira_key]
  matches = l[:matches]
  result = jira_get_issue(jira_key)
  next unless result
  fields = result['fields']
  description = fields['description']
  matches.each do |m|
    j_key = assembla_id_to_jira_key[m[1..-1]]
    a_id = jira_key_to_assembla_id[j_key]
    unless /#{j_key}/.match?(description)
      puts "#{id} #{number} #{jira_key}: cannot find #{j_key} (##{a_id})"
    end
  end
end
