# frozen_string_literal: true

load './lib/common.rb'

if JIRA_SERVER_TYPE == 'hosted'
  puts 'No need to run this script for a hosted server.'
  exit
end

puts "Sorry, but this has not yet implemented. Please be patient...\n\nFor now you must rank issues manually in Jira."
