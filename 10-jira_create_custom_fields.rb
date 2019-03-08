# frozen_string_literal: true

load './lib/common.rb'
load './lib/screens.rb'

# --- JIRA fields --- #

@fields_jira = jira_get_fields
goodbye('Cannot get fields!') unless @fields_jira

def jira_get_field_by_name(name)
  @fields_jira.find{ |field| field['name'] == name }
end

# --- JIRA screens --- #

project = jira_get_project_by_name(JIRA_API_PROJECT_NAME)

unless ARGV.length == 2
  goodbye('Missing screens ids, ARGV1=screen_id1 and ARGV2=screen_id2 (see README.md).')
end
goodbye("Invalid ARGV1='#{ARGV[0]}', must be a number") unless /^\d+$/.match?(ARGV[0])
goodbye("Invalid ARGV2='#{ARGV[1]}', must be a number") unless /^\d+$/.match?(ARGV[1])
@screens = [{ id: ARGV[0] }, { id: ARGV[1] }]

@customfield_name_to_id = {}
@customfield_id_to_name = {}

@all_custom_field_names = CUSTOM_FIELD_NAMES.dup

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

unless missing_fields.length.zero?
  nok = []
  missing_fields.each do |name|
    description = "Custom field '#{name}'"
    custom_field = jira_create_custom_field(name, description,
                                            'com.atlassian.jira.plugin.system.customfieldtypes:readonlyfield',
                                            'com.atlassian.jira.plugin.system.customfieldtypes:textsearcher')
    unless custom_field
      nok << name
    end
  end
  len = nok.length
  unless len.zero?
    goodbye("Custom field#{len == 1 ? '' : 's'} '#{nok.join('\',\'')}' #{len == 1 ? 'is' : 'are'} missing, please define in Jira and make sure to attach it to the appropriate screens")
  end
  # Reload fields since new ones have been created.
  @fields_jira = jira_get_fields
end

@screens.each do |screen|
  screen[:availableFields] = jira_get_screen_available_fields(project['key'], screen[:id])
  unless screen[:availableFields]
    goodbye("Looks like screen_id='#{screen[:id]}' doesn't exist")
  end
  screen[:tabs] = jira_get_screen_tabs(project['key'], screen[:id])
  unless screen[:tabs].length.positive?
    goodbye("Looks like screen_id='#{screen[:id]}' has no tabs")
  end
  screen[:tabs].each do |tab|
    tab[:fields] = jira_get_screen_tab_fields(project['key'], screen[:id], tab['id'])
  end
end

@all_custom_field_names.each do |name|
  @screens.each do |screen|
    next unless screen[:availableFields].detect { |field| name.casecmp(field['name']).zero? }
    field = jira_get_field_by_name(name)
    result = jira_add_field(screen[:id], screen[:tabs][0]['id'],field['id'])
    goodbye("Cannot add field='#{name}'") unless result
    screen[:tabs][0][:fields] << field
  end
end

@screens.each do |screen|
  tab = screen[:tabs][0]
  puts "\nScreen: id=#{screen[:id]} Tab: id='#{tab['id']}', name='#{tab['name']}' fields=#{tab[:fields].length}"
  tab[:fields].sort { |x, y| x['name'] <=> y['name'] }.each do |field|
    puts "* id='#{field['id']}', name='#{field['name']}'" if @all_custom_field_names.include?(field['name'])
  end
end
