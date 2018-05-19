# frozen_string_literal: true

load './lib/common.rb'
load './lib/users-assembla.rb'

# --- ASSEMBLA Tickets --- #

tickets_assembla_csv = "#{OUTPUT_DIR_ASSEMBLA}/tickets.csv"
milestones_assembla_csv = "#{OUTPUT_DIR_ASSEMBLA}/milestones-all.csv"
tags_assembla_csv = "#{OUTPUT_DIR_ASSEMBLA}/ticket-tags.csv"
associations_assembla_csv = "#{OUTPUT_DIR_ASSEMBLA}/ticket-associations.csv"

@tickets_assembla = csv_to_array(tickets_assembla_csv)
@milestones_assembla = csv_to_array(milestones_assembla_csv)
@tags_assembla = csv_to_array(tags_assembla_csv)
@associations_assembla = csv_to_array(associations_assembla_csv)

# --- Filter by date if TICKET_CREATED_ON is defined --- #
tickets_created_on = get_tickets_created_on

puts "Milestones: #{@milestones_assembla.length}"
puts "Tags: #{@tags_assembla.length}"
puts "Associations: #{@associations_assembla.length}"
puts "Users: #{@users_assembla.length}"

if tickets_created_on
  puts "Filter newer than: #{tickets_created_on}"
  tickets_initial = @tickets_assembla.length
  @tickets_assembla.select! { |item| item_newer_than?(item, tickets_created_on) }
  puts "Tickets: #{tickets_initial} => #{@tickets_assembla.length} ∆#{tickets_initial - @tickets_assembla.length}"
else
  puts "Tickets: #{@tickets_assembla.length}"
end

# Custom fields
@custom_fields = {}
@tickets_assembla.each do |ticket|
  c_fields = ticket['custom_fields']
  unless c_fields&.empty?
    fields = JSON.parse(c_fields.gsub(/=>/,': '))
    fields.each do |k, v|
      @custom_fields[k] = [] unless @custom_fields[k]
      @custom_fields[k] << v unless v&.empty? || @custom_fields[k].include?(v)
    end
  end
end

puts "\nTotal custom fields: #{@custom_fields.keys.length}"

@custom_fields.keys.each do |k|
  custom_field = @custom_fields[k]
  puts "\nTotal #{k} #{custom_field.length}"
  custom_field.sort.each do |name|
    puts "* #{name}"
  end
end

# --- JIRA Tickets --- #

issue_types_jira_csv = "#{OUTPUT_DIR_JIRA}/jira-issue-types.csv"
attachments_jira_csv = "#{OUTPUT_DIR_JIRA}/jira-attachments-download.csv"

@issue_types_jira = csv_to_array(issue_types_jira_csv)
@attachments_jira = csv_to_array(attachments_jira_csv)

@list_of_images = {}
@attachments_jira.each do |attachment|
  @list_of_images[attachment['assembla_attachment_id']] = attachment['filename']
end

puts "\nAttachments: #{@attachments_jira.length}"
puts

@fields_jira = []

@is_not_a_user = []
@cannot_be_assigned_issues = []

# This is populated as the tickets are created.
@assembla_number_to_jira_key = {}

def jira_get_field_by_name(name)
  @fields_jira.find{ |field| field['name'] == name }
end

# 0 - Parent (ticket2 is parent of ticket1 and ticket1 is child of ticket2)
# 5 - Story (ticket2 is story and ticket1 is subtask of the story)
def get_parent_issue(ticket)
  issue = nil
  ticket1_id = ticket['id']
  association = @associations_assembla.find { |assoc| assoc['ticket1_id'] == ticket1_id && assoc['relationship_name'].match(/story|parent/) }
  if association
    ticket2_id = association['ticket2_id']
    issue = @jira_issues.find{|iss| iss[:assembla_ticket_id] == ticket2_id}
  else
    puts "Could not find parent_id for ticket_id=#{ticket1_id}"
  end
  issue
end

def get_labels(ticket)
  labels = ['assembla']
  @tags_assembla.each do |tag|
    if tag['ticket_number'] == ticket['number']
      labels << tag['name'].tr(' ', '-')
    end
  end
  labels
end

def get_milestone(ticket)
  id = ticket['milestone_id']
  name = id && id.length.positive? ? (@milestone_id_to_name[id] || id) : 'unknown milestone'
  { id: id, name: name }
end

def get_issue_type(ticket)
  result = case ticket['hierarchy_type'].to_i
           when 1
             { id: @issue_type_name_to_id['sub-task'], name: 'sub-task' }
           when 2
             { id: @issue_type_name_to_id['story'], name: 'story' }
           when 3
             { id: @issue_type_name_to_id['epic'], name: 'epic' }
           else
            if JIRA_ISSUE_DEFAULT_TYPE
             { id: @issue_type_name_to_id[JIRA_ISSUE_DEFAULT_TYPE], name: JIRA_ISSUE_DEFAULT_TYPE }
            else
             { id: @issue_type_name_to_id['task'], name: 'task' }
            end
           end

  # Ticket type is overruled if summary begins with the type, for example SPIKE or BUG.
  ASSEMBLA_TYPES_EXTRA.each do |s|
    # if ticket['summary'] =~ /^#{s}/i
    if /^#{s}/i.match?(ticket['summary'])
      result = { id: @issue_type_name_to_id[s], name: s }
      break
    end
  end
  result
end

def create_ticket_jira(ticket, counter, total)
  project_id = @project['id']
  ticket_id = ticket['id']
  ticket_number = ticket['number']
  summary = reformat_markdown(ticket['summary'], logins: @list_of_logins, images: @list_of_images, content_type: 'summary', tickets: @assembla_number_to_jira_key)
  created_on = ticket['created_on']
  completed_date = date_format_yyyy_mm_dd(ticket['completed_date'])
  reporter_id = ticket['reporter_id']
  assigned_to_id = ticket['assigned_to_id']
  priority = ticket['priority']
  reporter_name = @user_id_to_login[reporter_id]
  reporter_name.sub!(/@.*$/,'')
  reporter_email = @user_id_to_email[reporter_id]
  assignee_name = @user_id_to_login[assigned_to_id]
  priority_name = @priority_id_to_name[priority]
  status_name = ticket['status']
  story_rank = ticket['importance']
  story_points = ticket['story_importance']

  # Prepend the description text with a link to the original assembla ticket on the first line.
  description = "Assembla ticket [##{ticket_number}|#{ENV['ASSEMBLA_URL_TICKETS']}/#{ticket_number}] | "
  author_name = if reporter_name.nil? || reporter_name.length.zero? || @is_not_a_user.include?(reporter_name)
                  'unknown'
                else
                  "[~#{reporter_name}]"
                end
  description += "Author #{author_name} | "
  description += "Created on #{date_time(created_on)}\n\n"
  reformatted_description = "#{reformat_markdown(ticket['description'], logins: @list_of_logins, images: @list_of_images, content_type: 'description', tickets: @assembla_number_to_jira_key)}"
  description += reformatted_description

  labels = get_labels(ticket)

  custom_fields = JSON.parse(ticket['custom_fields'].gsub('=>',':'))
  custom_field = ASSEMBLA_CUSTOM_FIELD.empty? ? nil : custom_fields[ASSEMBLA_CUSTOM_FIELD]

  milestone = get_milestone(ticket)

  issue_type = get_issue_type(ticket)

  payload = {
    'create': {},
    'fields': {
      'project': { 'id': project_id },
      'summary': summary,
      'issuetype': { 'id': issue_type[:id] },
      'assignee': { 'name': assignee_name },
      'reporter': { 'name': reporter_name },
      'priority': { 'name': priority_name },
      'labels': labels,
      'description': description,

      # IMPORTANT: The following custom fields MUST be on the create issue screen for this project
      #  Admin > Issues > Screens > Configure screen > 'PROJECT_KEY: Scrum Default Issue Screen'
      # Assembla

      "#{@customfield_name_to_id['Assembla-Id']}": ticket_number,
      "#{@customfield_name_to_id['Assembla-Status']}": status_name,
      "#{@customfield_name_to_id['Assembla-Milestone']}": milestone[:name],
      "#{@customfield_name_to_id['Assembla-Completed']}": completed_date
    }
  }

  if custom_field
    assembla_custom_field = "Assembla-#{ASSEMBLA_CUSTOM_FIELD}"
    payload[:fields]["#{@customfield_name_to_id[assembla_custom_field]}".to_sym] = custom_field
  end

  if JIRA_SERVER_TYPE == 'hosted'
    payload[:fields]["#{@customfield_name_to_id['Rank']}".to_sym] = story_rank
  end

  # Reporter is required
  if reporter_name.nil? || reporter_name.length.zero? || @is_not_a_user.include?(reporter_name)
    payload[:fields]["#{@customfield_name_to_id['Assembla-Reporter']}".to_sym] = payload[:fields][:reporter][:name]
    payload[:fields][:reporter][:name] = JIRA_API_UNKNOWN_USER
    reporter_name = JIRA_API_UNKNOWN_USER
  end

  if @cannot_be_assigned_issues.include?(assignee_name)
    payload[:fields]["#{@customfield_name_to_id['Assembla-Assignee']}".to_sym] = payload[:fields][:assignee][:name]
    payload[:fields][:assignee][:name] = ''
  end

  case issue_type[:name]
  when 'epic'
    epic_name = (summary =~ /^epic: /i ? summary[6..-1] : summary)
    payload[:fields]["#{@customfield_name_to_id['Epic Name']}".to_sym] = epic_name
  when 'story'
    payload[:fields]["#{@customfield_name_to_id['Story Points']}".to_sym] = story_points.to_i
  when 'sub-task'
    parent_issue = get_parent_issue(ticket)
    payload[:fields][:parent] = {}
    payload[:fields][:parent][:id] = parent_issue ? parent_issue[:jira_ticket_id] : nil
  end

  jira_ticket_id = nil
  jira_ticket_key = nil
  message = nil
  ok = false
  retries = 0
  begin
    response = RestClient::Request.execute(method: :post, url: URL_JIRA_ISSUES, payload: payload.to_json, headers: JIRA_HEADERS_ADMIN)
    body = JSON.parse(response.body)
    jira_ticket_id = body['id']
    jira_ticket_key = body['key']
    message = "id='#{jira_ticket_id}' key='#{jira_ticket_key}'"

    # Check for unresolved ticket links that have to be resolved later.
    summary_ticket_links = !/#\d+/.match(summary).nil?
    description_ticket_links = !/#\d+/.match(reformatted_description).nil?
    if summary_ticket_links || description_ticket_links
      @jira_ticket_links << {
          jira_ticket_key: jira_ticket_key,
          summary: summary_ticket_links,
          description: description_ticket_links
      }
    end

    ok = true
  rescue RestClient::ExceptionWithResponse => e
    error = JSON.parse(e.response)
    message = error['errors'].map { |k, v| "#{k}: #{v}"}.join(' | ')
    retries += 1
    recover = false
    if retries < MAX_RETRY
      error['errors'].each do |err|
        key = err[0]
        reason = err[1]
        case key
        when 'assignee'
          case reason
          when /cannot be assigned issues/i
            payload[:fields]["#{@customfield_name_to_id['Assembla-Assignee']}".to_sym] = payload[:fields][:assignee][:name]
            payload[:fields][:assignee][:name] = ''
            puts "Cannot be assigned issues: #{assignee_name}"
            @cannot_be_assigned_issues << assignee_name
            recover = true
          end
        when 'reporter'
          case reason
          when /is not a user/i
            payload[:fields]["#{@customfield_name_to_id['Assembla-Reporter']}".to_sym] = payload[:fields][:reporter][:name]
            payload[:fields][:reporter][:name] = JIRA_API_UNKNOWN_USER
            puts "Is not a user: #{reporter_name}"
            @is_not_a_user << reporter_name
            recover = true
          end
        when 'issuetype'
          case reason
          when /is a sub-task but parent issue key or id not specified/i
            issue_type = {
              id: @issue_type_name_to_id['task'],
              name: 'task'
            }
            payload[:fields][:issuetype][:id] = issue_type[:id]
            payload[:fields].delete(:parent)
            recover = true
          end
          when /customfield_/
            key += " (#{@customfield_id_to_name[key]})"
        end
        puts "POST #{URL_JIRA_ISSUES} payload='#{payload.inspect.sub(/:description=>"[^"]+",/,':description=>"...",')}' => NOK (key='#{key}', reason='#{reason}')" unless recover
      end
    end
    retry if retries < MAX_RETRY && recover
  rescue => e
    message = e.message
  end

  dump_payload = ok ? '' : ' ' + payload.inspect.sub(/:description=>"[^"]+",/,':description=>"...",')
  percentage = ((counter * 100) / total).round.to_s.rjust(3)
  puts "#{percentage}% [#{counter}|#{total}|#{issue_type[:name].upcase}] POST #{URL_JIRA_ISSUES} #{ticket_number}#{dump_payload} => #{ok ? '' : 'N'}OK (#{message}) retries = #{retries}#{summary_ticket_links || description_ticket_links ? ' (*)' : ''}"

  if ok
    if ticket['description'] != reformatted_description
      @tickets_diffs << {
        assembla_ticket_id: ticket_id,
        assembla_ticket_number: ticket_number,
        jira_ticket_id: jira_ticket_id,
        jira_ticket_key: jira_ticket_key,
        project_id: project_id,
        before: ticket['description'],
        after: reformatted_description
      }
    end
    @assembla_number_to_jira_key[ticket_number] = jira_ticket_key
  end

  {
    result: (ok ? 'OK' : 'NOK'),
    retries: retries,
    message: (ok ? '' : message.gsub(' | ', "\n\n")),
    jira_ticket_id: jira_ticket_id,
    jira_ticket_key: jira_ticket_key,
    project_id: project_id,
    summary: summary,
    issue_type_id: issue_type[:id],
    issue_type_name: issue_type[:name],
    assignee_name: assignee_name,
    reporter_name: reporter_name,
    priority_name: priority_name,
    status_name: status_name,
    labels: labels.join('|'),
    description: description,
    assembla_ticket_id: ticket_id,
    assembla_ticket_number: ticket_number,
    custom_field: custom_field,
    milestone_name: milestone[:name],
    story_rank: story_rank
  }
end

# Ensure that the project exists, otherwise try and create it and if that fails ask the user to create it first.
@project = jira_get_project_by_name(JIRA_API_PROJECT_NAME)
if @project
  puts "Found project '#{JIRA_API_PROJECT_NAME}' id='#{@project['id']}' key='#{@project['key']}'"
else
  @project = jira_create_project(JIRA_API_PROJECT_NAME, JIRA_API_PROJECT_TYPE)
  if @project
    puts "Created project '#{JIRA_API_PROJECT_NAME}' id='#{@project['id']}' key='#{@project['key']}'"
  else
    goodbye("You must first create a Jira project called '#{JIRA_API_PROJECT_NAME}' in order to continue (see README.md)")
  end
end

# --- USERS --- #

puts "\nTotal users: #{@user_id_to_login.length}"

@user_id_to_login.each do |k, v|
  puts "* #{k} #{v}"
end

# Make sure that the unknown user exists and is active, otherwise try and create
puts "\nUnknown user:"
if JIRA_API_UNKNOWN_USER && JIRA_API_UNKNOWN_USER.length
  user = jira_get_user(JIRA_API_UNKNOWN_USER, false)
  if user
    goodbye("Please activate Jira unknown user '#{JIRA_API_UNKNOWN_USER}' (see README.md)") unless user['active']
    puts "Found Jira unknown user '#{JIRA_API_UNKNOWN_USER}' => OK"
  else
    user = {}
    user['login'] = JIRA_API_UNKNOWN_USER
    user['name'] = JIRA_API_UNKNOWN_USER
    result = jira_create_user(user)
    goodbye("Cannot find Jira unknown user '#{JIRA_API_UNKNOWN_USER}', make sure that has been created and enabled (see README.md).") unless result
    puts "Created Jira unknown user '#{JIRA_API_UNKNOWN_USER}'"
  end
else
  goodbye("Please define 'JIRA_API_UNKNOWN_USER' in the .env file (see README.md)")
end

# --- MILESTONES --- #

puts "\nTotal milestones: #{@milestones_assembla.length}"

@milestone_id_to_name = {}
@milestones_assembla.each do |milestone|
  @milestone_id_to_name[milestone['id']] = milestone['title']
end

@milestone_id_to_name.each do |k, v|
  puts "* #{k} #{v}"
end

# --- ISSUE TYPES --- #

# IMPORTANT: the sub-tasks MUST be done last in order to be able to be associated with the parent tasks/stories.
@issue_types = %w(epic story task bug sub-task)

puts "\nTotal issue types: #{@issue_types_jira.length}"

@issue_type_name_to_id = {}
@issue_types_jira.each do |type|
  @issue_type_name_to_id[type['name'].downcase] = type['id']
end

@issue_type_name_to_id.each do |k, v|
  puts "* #{v} #{k}"
end

# Make sure that all issue types are indeed available.
@missing_issue_types = []
@issue_types.each do |issue_type|
  @missing_issue_types << issue_type unless @issue_type_name_to_id[issue_type]
end

if @missing_issue_types.length.positive?
  goodbye("Missing issue types: #{@missing_issue_types.join(',')}, please create (see README.md) and re-run jira_get_info script.")
end

# --- PRIORITIES --- #

puts "\nPriorities:"

@priority_id_to_name = {}
@priorities_jira = jira_get_priorities
if @priorities_jira
  @priorities_jira.each do |priority|
    @priority_id_to_name[priority['id']] = priority['name']
  end
else
  goodbye('Cannot get priorities!')
end

@priority_id_to_name.each do |k, v|
  puts "#{k} #{v}"
end

# --- JIRA fields --- #

puts "\nJira fields:"

@fields_jira = jira_get_fields
goodbye('Cannot get fields!') unless @fields_jira

@fields_jira.sort_by { |k| k['id'] }.each do |field|
  puts "#{field['id']} '#{field['name']}'" unless field['custom']
end

# --- JIRA custom fields --- #

puts "\nJira custom fields:"

@fields_jira.sort_by { |k| k['id'] }.each do |field|
  puts "#{field['id']} '#{field['name']}'" if field['custom'] && field['name'] !~ /Assembla/
end

# --- JIRA custom Assembla fields --- #

puts "\nJira custom Assembla fields:"

@fields_jira.sort_by { |k| k['id'] }.each do |field|
  puts "#{field['id']} '#{field['name']}'" if field['custom'] && field['name'] =~ /Assembla/
end

@customfield_name_to_id = {}
@customfield_id_to_name = {}

@all_custom_field_names = CUSTOM_FIELD_NAMES.dup

@all_custom_field_names << "Assembla-#{ASSEMBLA_CUSTOM_FIELD}" unless ASSEMBLA_CUSTOM_FIELD.empty?

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
    custom_field = jira_create_custom_field(name, description, 'com.atlassian.jira.plugin.system.customfieldtypes:readonlyfield')
    unless custom_field
      nok << name
    end
  end
  len = nok.length
  unless len.zero?
    goodbye("Custom field#{len == 1 ? '' : 's'} '#{nok.join('\',\'')}' #{len == 1 ? 'is' : 'are'} missing, please define in Jira and make sure to attach it to the appropriate screens (see README.md)")
  end
end

# --- Import all Assembla tickets into Jira --- #

@total_tickets = @tickets_assembla.length

# IMPORTANT: Make sure that the tickets are ordered chronologically from first (oldest) to last (newest)
@tickets_assembla.sort! { |x, y| x['created_on'] <=> y['created_on'] }

@jira_issues = []
@jira_ticket_links = []

@tickets_diffs = []

# Some sanity checks just in case
@invalid_reporters = []
@tickets_assembla.each do |ticket|
  ticket_id = ticket['id']
  reporter_id = ticket['reporter_id']
  reporter_name = @user_id_to_login[reporter_id]
  reporter_email = @user_id_to_email[reporter_id]
  unless reporter_name && reporter_name.length.positive? && reporter_email && reporter_email.length.positive?
    @invalid_reporters << {
        ticket_id: ticket_id,
        reporter_id: reporter_id,
        reporter_name: reporter_name,
        reporter_email: reporter_email
    }
  end
end

if @invalid_reporters.length.positive?
  puts "\nInvalid reporters: #{@invalid_reporters.length}"
  @invalid_reporters.each do |reporter|
    puts "ticket_id='#{reporter[:ticket_id]}' reporter: id='#{reporter[:reporter_id]}', name='#{reporter[:reporter_name]}', email='#{reporter[:reporter_email]}'"
  end
  goodbye('Please fix before continuing')
end

puts "\nReporters => OK"

@tickets_assembla.each_with_index do |ticket, index|
  @jira_issues << create_ticket_jira(ticket, index + 1, @total_tickets)
end

puts "Total tickets: #{@total_tickets}"
tickets_jira_csv = "#{OUTPUT_DIR_JIRA}/jira-tickets.csv"
write_csv_file(tickets_jira_csv, @jira_issues)

puts "Total unresolved ticket links: #{@jira_ticket_links.length}"
puts "[#{@jira_ticket_links.map { |rec| rec[:jira_ticket_key] }.join(',')}]"
ticket_links_jira_csv = "#{OUTPUT_DIR_JIRA}/jira-ticket-links.csv"
write_csv_file(ticket_links_jira_csv, @jira_ticket_links)

tickets_diffs_jira_csv = "#{OUTPUT_DIR_JIRA}/jira-tickets-diffs.csv"
write_csv_file(tickets_diffs_jira_csv, @tickets_diffs)
