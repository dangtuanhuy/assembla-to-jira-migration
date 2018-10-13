# frozen_string_literal: true
# require 'json'

load './lib/common.rb'

@assembla_2_jira_custom = [
    { title: 'List', custom: 'com.atlassian.jira.plugin.system.customfieldtypes:select', options: true },
    { title: 'Team List', custom: 'com.atlassian.teams:rm-teams-custom-field-team', options: false },
    { title: 'Numeric', custom: 'com.atlassian.jira.plugin.system.customfieldtypes:float', options: false },
    { title: 'Text', custom: 'com.atlassian.jira.plugin.system.customfieldtypes:textfield', options: false },
]

@custom_plugin_names = @assembla_2_jira_custom.map { |f| f[:custom] }
@customfield_name_to_id = {}
@customfield_id_to_name = {}

# --- Assembla Custom fields --- #

custom_fields_csv = "#{OUTPUT_DIR_ASSEMBLA}/tickets-custom-fields.csv"

@custom_fields_assembla = csv_to_array(custom_fields_csv)
goodbye('Cannot get custom fields!') unless @custom_fields_assembla.length.nonzero?

@custom_fields_jira = jira_get_fields.select do |field|
  field['custom'] && @custom_plugin_names.index(field['schema']['custom']) && field['name'] !~ /^Assembla/
end

puts "\nFound the following Jira custom fields:\n\n"

@custom_fields_jira.each do |field|
  puts  "* #{field['name']}"
end

missing_fields = []
@custom_fields_assembla.each do |field_assembla|
  name = field_assembla['title']
  field = @custom_fields_jira.detect {|field_jira| field_jira['name'] == name}
  if field
    id = field['id']
    @customfield_name_to_id[name] = id
    @customfield_id_to_name[id] = name
  else
    missing_fields << field_assembla
  end
end

if missing_fields.length.nonzero?
  puts "\nMissing Assembla custom fields:"
  missing_fields.each do |field|
    puts  "* #{field['title']}"
  end
else
  puts "\nThere are no missing Assembla custom fields, so exit."
  exit
end

# --- Jira Custom fields --- #

@custom_fields_jira = jira_get_fields
@custom_field_names_jira = @custom_fields_jira.map { |field| field['title']}

@custom_field_names.each do |field|
  missing_field_names
end

@custom_fields_assembla.each do | field |
  type = field['type']
  title = field['title']
  list_options = type == 'List' ? JSON.parse(field['list_options']) : nil
  @list << {type: type, title: title, options: list_options}
end

@list.each do | item |
  options = item[:options].nil? ? nil : item[:options].to_s
  puts "Type: #{item[:type]}, Title: #{item[:title]} #{options}"
end

# --- JIRA custom fields --- #
@fields_jira = jira_get_fields

puts "\nJira custom fields:"

@fields_jira.sort_by { |k| k['id'] }.each do |field|
  # puts "#{field['id']} '#{field['name']}'" if field['custom'] && field['name'] !~ /Assembla/
  puts field.inspect if field['custom'] && /^my/.match(field['name'])
end

nok = []
missing_fields.each do |name|
  description = "Custom field '#{name}'"
  custom_field = jira_create_custom_field(name, description, 'com.atlassian.jira.plugin.system.customfieldtypes:readonlyfield')
  unless custom_field
    nok << name
  end
end
len = nok.length
unless len.zero?
  goodbye("Custom field#{len == 1 ? '' : 's'} '#{nok.join('\',\'')}' #{len == 1 ? 'is' : 'are'} missing, please define in Jira and make sure to attach it to the appropriate screens (see README.md)")
end

