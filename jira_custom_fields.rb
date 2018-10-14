# frozen_string_literal: true

load './lib/common.rb'

@custom_fields = jira_get_fields

puts "Custom fields: #{@custom_fields.length}"

@custom_fields.each do |field|
  puts field.inspect
end

