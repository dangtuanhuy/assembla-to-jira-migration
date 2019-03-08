# frozen_string_literal: true

load './lib/common.rb'

# This script verifies that all of the original tickets exported from Assembla have been imported
# successfully into Jira.
#
# Once the migration is completed goto the given project > issues and filters > all issues > advanced search
# and enter "project = "Project-Key" and Assembla-Id !~ empty ORDER BY key asc". This list can be exported to
# a file named 'verify-imported-tickets.csv' with the column names 'assembla_id' and 'jira_key'.

assembla_tickets = csv_to_array("#{OUTPUT_DIR_ASSEMBLA}/tickets.csv")
jira_issues = csv_to_array('./z-imported-tickets.csv')

puts "Total assembla tickets: #{assembla_tickets.length}"
puts "Total jira issues:      #{jira_issues.length}"

is_issue = {}
jira_issues.each do |issue|
  is_issue[issue['assembla_id']] = true
end

missing_tickets = []
assembla_tickets.each do |ticket|
  missing_tickets << ticket unless is_issue[ticket['number']]
end

puts "Missing tickets: #{missing_tickets.length}"
if missing_tickets.length.nonzero?
  missing_tickets.each do |ticket|
    puts "* #{ticket['id']} #{ticket['number']}"
  end
end