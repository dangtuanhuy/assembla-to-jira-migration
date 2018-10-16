# frozen_string_literal: true

custom_fields_assembla_csv = "#{OUTPUT_DIR_ASSEMBLA}/tickets-custom-fields.csv"
@custom_fields_assembla = csv_to_array(custom_fields_assembla_csv)
goodbye('Cannot get custom fields!') unless @custom_fields_assembla.length.nonzero?

# Convert custom field title to type: List, Numeric, Team List or Text.
@custom_title_to_type = {}
@custom_fields_assembla.each do |item|
  @custom_title_to_type[item['title']] = item['type']
end

def jira_get_issue_createmeta(project_key, issue_type_name)
  result = []
  url = "#{JIRA_API_HOST}/issue/createmeta?projectKeys=#{project_key}&issuetypeNames=#{issue_type_name}&expand=projects.issuetypes.fields"
  begin
    response = RestClient::Request.execute(method: :get, url: url, headers: JIRA_HEADERS_ADMIN)
    result = JSON.parse(response.body)
    puts "GET #{url} => OK (#{result.length})"
  rescue => e
    puts "GET #{url} => NOK (#{e.message})"
  end
  result
end

def jira_get_list_option_id(name, value)
  result = nil
  list = @createmeta_lookup.detect { |l| l[:name] == name }
  if list
    option = list[:options].detect { |o| o[:value] == value }
    if option
      result = option[:id]
    end
  end
  result
end

def jira_get_list_option_value(name, id)
  result = nil
  list = @createmeta_lookup.detect { |l| l[:name] == name }
  if list
    option = list[:options].detect { |o| o[:id] == id }
    if option
      result = option[:value]
    end
  end
  result
end

project = jira_get_project_by_name(JIRA_API_PROJECT_NAME)

result = jira_get_issue_createmeta(project['key'], 'Story')

@createmeta_fields = result['projects'][0]['issuetypes'][0]['fields']

# lookup = [{
#   id: '',
#   name: '',
#   options: [{id: '', value: ''},...]
# },...]
@createmeta_lookup = []

def init(b)
  @createmeta_fields.each do |field|
    custom_field = field[0]
    h = field[1]
    name = h['name']
    found = @custom_fields_assembla.detect {|f| f['title'] == name}
    next unless found && found['type'] == 'List'
    list = {id: custom_field, name: name, options: []}
    puts "#{custom_field} => '#{name}'" unless b
    h['allowedValues'].each do |v|
      puts "id: #{v['id']} => value: '#{v['value']}'" unless b
      list[:options] << {id: v['id'], value: v['value']}
      if b
        id = jira_get_list_option_id(name, v['value'])
        if id != v['id']
          puts "TEST id => NOK"
          exit
        end
        value = jira_get_list_option_value(name, v['id'])
        if value != v['value']
          puts "TEST value => NOK"
          exit
        end
      end
    end
    next if b
    puts '---'
    @createmeta_lookup << list
  end
end

init(false)
init(true)
puts "Test => OK"