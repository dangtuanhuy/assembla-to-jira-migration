# frozen_string_literal: true

load './lib/common.rb'
load './lib/common-confluence.rb'
load './lib/confluence-api.rb'

def abort(message)
  puts "ERROR: #{message} => EXIT"
  exit
end

def format_created_at(created_at)
  created_at.sub(/\.[^.]*$/, '').tr('T', ' ')
end

# result,retries,message,jira_ticket_id,jira_ticket_key,project_id,summary,issue_type_id,issue_type_name,
# assignee_name,reporter_name,priority_name,status_name,labels,description,assembla_ticket_id,assembla_ticket_number,
# milestone_name,story_rank
tickets_jira_csv = "#{OUTPUT_DIR_JIRA}/jira-tickets.csv"
@jira_tickets_csv = csv_to_array(tickets_jira_csv).select { |ticket| ticket['result'] == 'OK' }

tickets_jira_csv_org = "#{OUTPUT_DIR_JIRA}/jira-tickets.csv.org"
if File.exist?(tickets_jira_csv_org)
  @jira_tickets_csv_org = csv_to_array(tickets_jira_csv_org).select { |ticket| ticket['result'] == 'OK' }
end

# Check for duplicates just in case.
@assembla_nr_to_jira_key = {}
duplicates = []
if File.exist?(tickets_jira_csv_org)
  @jira_tickets_csv_org.sort_by { |ticket| ticket['assembla_ticket_number'].to_i }.each do |ticket|
    nr = ticket['assembla_ticket_number']
    key = ticket['jira_ticket_key']
    if @assembla_nr_to_jira_key[nr]
      duplicates << { nr: nr, key: key }
    else
      @assembla_nr_to_jira_key[nr] = key
    end
  end
end

@jira_tickets_csv.sort_by { |ticket| ticket['assembla_ticket_number'].to_i }.each do |ticket|
  nr = ticket['assembla_ticket_number']
  key = ticket['jira_ticket_key']
  if @assembla_nr_to_jira_key[nr]
    duplicates << { nr: nr, key: key }
  else
    @assembla_nr_to_jira_key[nr] = key
  end
end

if duplicates.length.positive?
  puts "\nDuplicates found: #{duplicates}\n"
  duplicates.each do |duplicate|
    puts "* #{duplicate[:nr]} #{duplicate[:key]}"
  end
end

# id,page_name,contents,status,version,position,wiki_format,change_comment,parent_id,space_id,
# user_id,created_at,updated_at
wiki_assembla_csv = "#{OUTPUT_DIR_ASSEMBLA}/wiki-pages.csv"
@wiki_assembla = []
csv_to_array(wiki_assembla_csv).each_with_index do |wiki, index|
  wiki['contents'] = fix_html(wiki['contents'])
  @wiki_assembla << wiki
end

write_csv_file(WIKI_FIXED_CSV, @wiki_assembla)

@wiki_assembla = csv_to_array(WIKI_FIXED_CSV)

# id,number,summary,description,priority,completed_date,component_id,created_on,permission_type,importance,is_story,
# milestone_id,notification_list,space_id,state,status,story_importance,updated_at,working_hours,estimate,
# total_estimate,total_invested_hours,total_working_hours,assigned_to_id,reporter_id,custom_fields,hierarchy_type,
# due_date,assigned_to_name,picture_url
tickets_assembla_csv = "#{OUTPUT_DIR_ASSEMBLA}/tickets.csv"
@tickets_assembla = csv_to_array(tickets_assembla_csv)

# id,login,name,picture,email,organization,phone
users_assembla_csv = "#{OUTPUT_DIR_ASSEMBLA}/users.csv"
@users_assembla = csv_to_array(users_assembla_csv)

@pages = {}
@created_pages = []

puts "\n--- Wiki pages: #{@wiki_assembla.length} ---\n"

@wiki_assembla.each do |wiki|
  id = wiki['id']
  # wiki['page_name'].tr!('_', ' ')
  page_name = wiki['page_name']
  abort "Duplicate id='#{id}'" if @pages[id]
  abort "Duplicate page_name='#{page_name}'" if @pages.detect { |_, value| value[:page]['page_name'] == page_name }
  @pages[id] = { page: wiki, children_ids: [] }
end

def show_page(id, offset = [])
  # puts "show_page() id='#{id}' offset=[#{offset.join(',')}]"
  pages_id = @pages[id]
  page = pages_id[:page]
  page_name = page['page_name']
  parent_id = page['parent_id'] ? "parent_id='#{page['parent_id']}'" : ''
  created_at = format_created_at(page['created_at'])
  children_ids = pages_id[:children_ids]
  children_ids = 'children_ids=' + (children_ids.length.positive? ? "#{children_ids.length} [#{children_ids.join(',')}]" : '0')

  tree = offset.join('-')
  tree += ' ' if tree.length.positive?
  puts "#{tree}id='#{id}' #{parent_id}created_at='#{created_at}' page_name='#{page_name}' #{children_ids}"
end

def show_page_tree(id, offset)
  # puts "show_page_tree() id='#{id}' offset=[#{offset.join(',')}]"
  show_page(id, offset)
  pages_id = @pages[id]
  children_ids = pages_id[:children_ids]
  return unless children_ids.length.positive?

  # Child pages sorted by created_at
  children_ids.sort_by! { |child_id| @pages[child_id][:page]['created_at'] }
  children_ids.each_with_index { |child_id, index| show_page_tree(child_id, offset.dup << index) }
end

def get_all_links
  links = []
  # wiki_assembla => id,page_name,contents,status,version,position,wiki_format,change_comment,parent_id,space_id,
  # user_id,created_at,updated_at
  @wiki_assembla.each do |wiki|
    counter = 0
    id = wiki['id']
    content = wiki['contents']
    title = wiki['page_name']

    # <img ... src="(value)" ... />
    content.scan(%r{<img(?:.*?)? src="(.*?)"(?:.*?)?/?>}).each do |m|
      value = m[0]
      next unless %r{^https?://www\.assembla.com/}.match?(value)

      counter += 1
      links << {
          id: id,
          counter: counter,
          title: title,
          tag: 'image',
          value: value,
          text: ''
      }
    end

    # <a ... href="(value)" ...>(title)</a>
    content.scan(%r{<a(?:.*?)? href="(.*?)"(?:.*?)?>(.*?)</a>}).each do |m|
      value = m[0]
      next unless %r{^https?://www\.assembla.com/}.match?(value)
      # https://www.assembla.com/spaces/green-in-a-box/wiki/Energy_Star_and_Utility_Sync_Feature_Requests
      #
      text = m[1]
      counter += 1
      links << {
          id: id,
          counter: counter,
          title: title,
          tag: 'anchor',
          value: value.sub('', ''),
          text: text
      }
    end
  end

  puts "\nLinks #{links.length}"
  unless links.length.zero?
    links.each do |l|
      if l[:counter] == 1
        puts "* #{l[:filename]} '#{l[:title]}'"
      end
      puts "  #{l[:counter].to_s.rjust(2, '0')} #{l[:tag]} #{l[:value]}"
    end
  end
  puts
  write_csv_file(LINKS_CSV, links)
end

def create_page_item(id, offset, counter, total)
  pages_id = @pages[id]
  page = pages_id[:page]
  page_id = page['id']
  title = page['page_name']
  body = page['contents']
  title_stripped = title.tr('_', ' ')
  parent_id = page['parent_id']
  user_id = page['user_id']
  user = @users_assembla.detect { |u| u['id'] == user_id }
  author = user ? user['name'] : ''
  created_at = format_created_at(page['created_at'])

  url = "#{WIKI}/#{title}"

  # Prepend the body with a link to the original Wiki page
  prefix = "<p>Created by #{author} at #{created_at}</p><p><a href=\"#{url}\" target=\"_blank\">Assembla Wiki</a></p><hr/>"

  # TODO: Remove the following line (only for testing)
  parent_id = nil
  puts 'Parent_id = NULL!'
  result, error = confluence_create_page(@space['key'], title_stripped, prefix, body, parent_id, counter, total)
  @created_pages <<
      if result
        {
            result: error ? 'NOK' : 'OK',
            page_id: page_id,
            id: result['id'],
            offset: offset.join('-'),
            title: title_stripped,
            author: author,
            created_at: created_at,
            body: error ? body : '',
            error: error ? error : ''
        }
      else
        {
            result: 'NOK',
            page_id: page_id,
            id: 0,
            offset: offset.join('-'),
            title: title_stripped,
            author: author,
            created_at: created_at,
            body: body,
            error: error
        }
      end
end

def download_item(dir, url, counter, total)
  filepath = "#{dir}/#{File.basename(url)}"
  pct = percentage(counter, total)
  return if File.exist?(filepath)
  begin
    content = RestClient::Request.execute(method: :get, url: url)
    IO.binwrite(filepath, content)
    puts "#{pct} GET url=#{url} => OK"
  rescue => error
    puts "#{pct} GET url=#{url} => NOK error='#{error.inspect}'"
  end
end

def download_all_images
  total = @all_images.length
  puts "\nDownloading #{total} images"
  @all_images.each_with_index do |image, index|
    download_item(IMAGES, image['value'], index + 1, total)
  end
  puts "\nDone!\n"
end

def download_all_documents
  total = @all_documents.length
  puts "\nDownloading #{total} images"
  @all_documents.each_with_index do |document, index|
    download_item(DOCUMENTS, document['value'], index + 1, total)
  end
  puts "\nDone!\n"
end

def show_all_items(items, verify_proc)
  list_ids = []
  items.each do |item|
    id = item['id']
    list_ids << id unless list_ids.include?(id)
  end
  list_ids.each_with_index do |id, index|
    page = @pages[id][:page]
    @links = items.select { |document| document['id'] == id }
    num = @links.length
    puts "#{index + 1}.0 id=#{id} title='#{page['page_name']}' => #{num} link#{num == 1 ? '' : 's'}"
    @links.each_with_index do |link, ind|
      value = link['value']
      padding = ' ' * ((index + 1).to_s.length + 1)
      puts "#{padding}#{ind + 1} #{value} => #{verify_proc.call(value) ? '' : 'N'}OK"
    end
  end
end

# --- Links --- #
# id,counter,title,tag,value,text
@all_links = csv_to_array(LINKS_CSV)
puts "\n--- Links: #{@all_links.length} ---"

# --- Images --- #
@all_images = @all_links.select { |link| link['tag'] == 'image' }
puts "\n--- Images: #{@all_images.length} ---"
# verify_proc = proc do |value|
#   File.exist?("#{IMAGES}/#{File.basename(value)}")
# end
show_all_items(@all_images, lambda { |value| File.exist?("#{IMAGES}/#{File.basename(value)}") })

# --- Anchors (documents + wikis) #
@all_anchors = csv_to_array(LINKS_CSV).select { |link| link['tag'] == 'anchor' }.sort_by { |wiki| wiki['value'] }
puts "\n--- Anchors: #{@all_anchors.length} ---"

# --- Documents --- #
@all_documents = @all_anchors.select { |anchor| anchor['value'].match(%r{/documents/}) }
puts "\n--- Documents: #{@all_documents.length} ---"
show_all_items(@all_documents, lambda { |value| File.exist?("#{DOCUMENTS}/#{File.basename(value)}") })

# --- Tickets --- #
@all_tickets = @all_anchors.select { |anchor| anchor['value'].match(%r{/tickets/}) }
puts "\n--- Tickets: #{@all_tickets.length} ---"
verify_proc = lambda do |value|
  value = value.sub(/#.*$/, '')
  ticket_nr = File.basename(value)
  @tickets_assembla.detect { |t| t['number'] == ticket_nr }
end
show_all_items(@all_tickets, verify_proc)

@all_wikis = @all_anchors.select { |anchor| anchor['value'].match(%r{/wiki/}) }
puts "\n--- Wikis: #{@all_wikis.length} ---"
verify_proc = lambda do |value|
  page_name = value.match(%r{/([^/]*)$})[1]
  @wiki_assembla.detect { |w| w['page_name'] == page_name }
end
show_all_items(@all_wikis, verify_proc)

download_all_images
download_all_documents

@pages.each do |id, value|
  parent_id = value[:page]['parent_id']
  next unless parent_id

  parent = @pages[parent_id]
  abort "Cannot find parent page with parent_id='#{parent_id}'" unless parent
  parent[:children_ids] << id
end

# Parent pages sorted by created_at
@parent_pages = @pages.reject { |_, value| value[:page]['parent_id'] }.sort_by { |_, value| value[:page]['created_at'] }
puts "\n--- Parents: #{@parent_pages.length} ---\n"
@parent_pages.each { |id, _| show_page(id) }

puts "\nDone\n"

# Child pages sorted by created_at
@child_pages = @pages.select { |_, value| value[:page]['parent_id'] }.sort_by { |_, value| value[:page]['created_at'] }
puts "\n--- Children: #{@child_pages.length} ---\n"
@child_pages.each { |id, _| show_page(id) }
puts "\nDone\n"

puts "\n--- Page Tree: #{@pages.length} ---\n"

count = 0
@parent_pages.each do |id, _|
  show_page_tree(id, [count])
  count += 1
end

total_parent_pages = @parent_pages.length
puts "\n--- Create parent pages: #{total_parent_pages} ---\n"

# TODO:
# count = 0
# total = @parent_pages.length
# @parent_pages.each do |id, _|
#   create_page_item(id, [count], count + 1, total_parent_pages)
#   count += 1
# end

count = 0
total_pages = @pages.length
@pages.each do |id, _|
  create_page_item(id, [count], count + 1, total_pages)
  count += 1
end

write_csv_file(CREATED_PAGES_CSV, @created_pages)

@nok = csv_to_array(CREATED_PAGES_CSV).select { |page| page['result'] == 'NOK' }
write_csv_file(CREATED_PAGES_NOK_CSV, @nok)

puts "\nDone\n"
