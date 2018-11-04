# frozen_string_literal: true

load './lib/common.rb'

# TODO
# def jira_create_custom_field_option(field_key, id, value)
#   result = nil
#   # $(app-key)__$(field-key)
#   payload = {
#       id: id,
#       value: value
#   }.to_json
#   url = "#{URL_JIRA_FIELDS}/#{field_key}/option/#{id}"
#   begin
#     response = RestClient::Request.execute(method: :put, url: url, payload: payload, headers: JIRA_HEADERS_ADMIN)
#     result = JSON.parse(response.body)
#     puts "POST #{url} payload='#{payload}' => OK (#{result['id']})"
#   rescue RestClient::ExceptionWithResponse => e
#     puts e.inspect
#     error = JSON.parse(e.response)
#     message = error['errors'].map {|k, v| "#{k}: #{v}"}.join(' | ')
#     puts "POST #{url} payload='#{payload}' => NOK (#{message})"
#   rescue => e
#     puts "POST #{url} payload='#{payload}' => NOK (#{e.message})"
#   end
#   result
# end

@assembla_to_jira_custom = [
  {
    name: 'List',
    jira_plugin: 'com.atlassian.jira.plugin.system.customfieldtypes:select',
    searcherKey: 'com.atlassian.jira.plugin.system.customfieldtypes:multiselectsearcher'
  },
  {
    name: 'Team List',
    jira_plugin: 'userpicker',
    searcherKey: 'userpickergroupsearcher'
  },
  {
    name: 'Numeric',
    jira_plugin: 'com.atlassian.jira.plugin.system.customfieldtypes:float',
    searcherKey: 'com.atlassian.jira.plugin.system.customfieldtypes:exactnumber'
  },
  {
    name: 'Text',
    jira_plugin: 'com.atlassian.jira.plugin.system.customfieldtypes:textfield',
    searcherKey: 'com.atlassian.jira.plugin.system.customfieldtypes:textsearcher'
  }
]

@custom_plugin_names = @assembla_to_jira_custom.map { |f| f[:jira_plugin] }
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
  puts "* #{field['name']}"
end

missing_fields = []
@custom_fields_assembla.each do |field_assembla|
  name = field_assembla['title']
  field = @custom_fields_jira.detect { |field_jira| field_jira['name'] == name }
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
    puts "* #{field['title']}"
  end
else
  puts "\nThere are no missing Assembla custom fields, so exit."
  exit
end

puts

nok = []
todo_list = []
missing_fields.each do |field|
  name = field['title']
  type = field['type']
  description = "Custom field '#{name}'"
  item = @assembla_to_jira_custom.detect { |f| f[:name] == type }
  goodbye("Cannot convert Assembla type to Jira custom") unless item
  jira_plugin = item[:jira_plugin]
  searcher_key = item[:searcherKey]
  custom_field = jira_create_custom_field(name, description, jira_plugin, searcher_key)
  if custom_field
    todo_list << field if item[:name] == 'List'
    # TODO
    # field_key = custom_field['key']
    # options = JSON.parse(field['list_options'])
    # options.each_with_index do |value, id|
    #   puts "jira_create_custom_field_option(field_key='#{field_key}', id='#{id + 1}', value='#{value}')"
    #   result = jira_create_custom_field_option(field_key, id + 1, value)
    # end
  else
    nok << name
  end
end

len = nok.length
unless len.zero?
  puts "\nCustom field#{len == 1 ? '' : 's'} '#{nok.join('\',\'')}' #{len == 1 ? 'is' : 'are'} missing, please define in Jira and make sure to attach it to the appropriate screens (see README.md)\n\n"
end

unless missing_fields.length.zero?
  puts "\nIMPORTANT: the following custom JIRA fields MUST be linked to the Scrum Default and Scrum Bug screens."
  missing_fields.each do |f|
    puts "* #{f['title']} => type='#{f['type']}'"
  end
end

unless todo_list.length.zero?
  puts "\nIMPORTANT: The following custom JIRA fields are LISTS and you MUST configure them and add the given options."
  todo_list.each do |f|
    puts "* #{f['title']} => #{f['list_options']}"
  end
end
