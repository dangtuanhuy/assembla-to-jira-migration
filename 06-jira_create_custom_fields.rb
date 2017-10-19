# frozen_string_literal: true

load './lib/common.rb'

# --- JIRA fields --- #

@fields_jira = jira_get_fields
goodbye('Cannot get fields!') unless @fields_jira

@default_fields_jira = @fields_jira.reject{ |field| field['custom'] }.sort_by { |field| field['id']}
@custom_fields_jira = @fields_jira.select{ |field| field['custom'] && field['name'] !~ /^assembla/i }.sort_by { |field| field['id']}
@assembla_fields_jira = @fields_jira.select{ |field| field['custom'] && field['name'] =~ /^assembla/i }.sort_by { |field| field['id']}

# --- JIRA default fields --- #

puts "\nJira default fields: #{@default_fields_jira.length}"
@default_fields_jira.each do |field|
  puts "* '#{field['id']}', '#{field['name']}'"
end

# --- JIRA custom fields --- #

puts "\nJira custom fields: #{@custom_fields_jira.length}"
@custom_fields_jira.each do |field|
  puts "* '#{field['id']}', '#{field['name']}'"
end

# --- JIRA assembla custom fields --- #

puts "\nJira assembla custom fields: #{@assembla_fields_jira.length}"
@assembla_fields_jira.each do |field|
  puts "* '#{field['id']}' '#{field['name']}'"
end

@customfield_name_to_id = {}
@customfield_id_to_name = {}

@all_custom_field_names = CUSTOM_FIELD_NAMES.dup

@all_custom_field_names << "Assembla-#{ASSEMBLA_CUSTOM_FIELD}" unless ASSEMBLA_CUSTOM_FIELD&.empty?

def jira_get_field_by_name(name)
  @fields_jira.find{ |field| field['name'] == name }
end

# --- Missing JIRA assembla custom fields --- #

missing_fields = []
@all_custom_field_names.each do |name|
  field = jira_get_field_by_name(name)
  if field
    id = field['id']
    @customfield_name_to_id[name] = id
    @customfield_id_to_name[id] = name
  else
    missing_fields << name
  end
end

if missing_fields.length.zero?
  puts "\nAll required assembla custom fields found."
else
  puts "\nTotal missing assembla custom fields: #{missing_fields.length}"
  nok = []
  missing_fields.each do |name|
    description = "Assembla custom field '#{name}'"
    custom_field = jira_create_custom_field(name, description, 'com.atlassian.jira.plugin.system.customfieldtypes:readonlyfield')
    unless custom_field
      nok << name
    end
  end
  len = nok.length
  unless len.zero?
    goodbye("Assembla custom field#{len == 1 ? '' : 's'} '#{nok.join('\',\'')}' #{len == 1 ? 'is' : 'are'} missing, please define in Jira and make sure to attach it to the appropriate screens")
  end
end

# --- Screens for JIRA assembla custom fields --- #

