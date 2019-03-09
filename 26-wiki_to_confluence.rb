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
@jira_tickets_csv_org = csv_to_array(tickets_jira_csv_org).select { |ticket| ticket['result'] == 'OK' } if File.exist?(tickets_jira_csv_org)

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
#
# wiki_format:
# 1 => text
# 3 => html

# TODO: uncomment the following lines when ready
# wiki_assembla_csv = "#{OUTPUT_DIR_ASSEMBLA}/wiki-pages.csv"
# @wiki_assembla = []
# csv_to_array(wiki_assembla_csv).each do |wiki|
#   wiki['contents'] = wiki['wiki_format'].to_i == 3 ? fix_html(wiki['contents']) : fix_text(wiki['contents'])
#   @wiki_assembla << wiki
# end
#
# write_csv_file(WIKI_FIXED_CSV, @wiki_assembla)

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

@total_wiki_pages = @wiki_assembla.length
puts "\n--- Wiki pages: #{@total_wiki_pages} ---\n"

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

def create_all_pages(id, offset)
  # puts "create_all_pages() id='#{id}' offset=[#{offset.join(',')}]"
  create_page_item(id, offset)
  @pages[id][:children_ids].each_with_index { |child_id, index| create_all_pages(child_id, offset.dup << index) }
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
      puts "* #{l[:filename]} '#{l[:title]}'" if l[:counter] == 1
      puts "  #{l[:counter].to_s.rjust(2, '0')} #{l[:tag]} #{l[:value]}"
    end
  end
  puts
  write_csv_file(LINKS_CSV, links)
end

def create_page_item(id, offset)
  pages_id = @pages[id]
  page = pages_id[:page]
  page_id = page['id']
  title = page['page_name']
  body = page['contents']
  title_stripped = title.tr('_', ' ')

  user_id = page['user_id']
  user = @users_assembla.detect { |u| u['id'] == user_id }
  author = user ? user['name'] : ''
  created_at = format_created_at(page['created_at'])

  parent_id = page['parent_id']
  if parent_id
    # Convert Assembla parent_id to Confluence created page id
    parent = @created_pages.detect { |p| p[:page_id] == parent_id }
    if parent
      parent_id = parent[:id]
    else
      puts "Cannot find parent of child id='#{page_id}' title='#{title}' parent_id='#{parent_id}' => set parent_id to nil"
      parent_id = nil
    end
  end

  url = "#{WIKI}/#{title}"

  # Prepend the body with a link to the original Wiki page
  prefix = "<p>Created by #{author} at #{created_at}</p><p><a href=\"#{url}\" target=\"_blank\">Assembla Wiki</a></p><hr/>"

  result, error = confluence_create_page(@space['key'],
                                         title_stripped,
                                         prefix,
                                         body,
                                         parent_id,
                                         @created_pages.length + 1,
                                         @total_wiki_pages)
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
        error: error || ''
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
  rescue RestClient::RuntimeError => e
    puts "#{pct} GET url=#{url} => NOK error='#{e.inspect}'"
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
show_all_items(@all_images, ->(value) { File.exist?("#{IMAGES}/#{File.basename(value)}") })

# --- Anchors (documents + wiki pages) #
@all_anchors = csv_to_array(LINKS_CSV).select { |link| link['tag'] == 'anchor' }.sort_by { |wiki| wiki['value'] }
puts "\n--- Anchors: #{@all_anchors.length} ---"

# --- Documents --- #
@all_documents = @all_anchors.select { |anchor| anchor['value'].match(%r{/documents/}) }
puts "\n--- Documents: #{@all_documents.length} ---"
show_all_items(@all_documents, ->(value) { File.exist?("#{DOCUMENTS}/#{File.basename(value)}") })

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

# TODO: uncomment the following two lines when ready
# download_all_images
# download_all_documents

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

def upload_all_pages
  puts "\n--- Create pages: #{@total_wiki_pages} ---\n"

  count = 0
  @parent_pages.each do |id, _|
    create_all_pages(id, [count])
    count += 1
  end

  puts

  write_csv_file(CREATED_PAGES_CSV, @created_pages)

  # Record failed created pages (NOK), if any
  write_csv_file(CREATED_PAGES_NOK_CSV, @created_pages.select { |page| page[:result] == 'NOK' })
end

def upload_all_images
  # result, page_id, id, offset, title, author, created_at, body, error
  @created_pages = csv_to_array(CREATED_PAGES_CSV)

  total_images = @all_images.length
  puts "\n--- Upload images: #{total_images} ---\n"

  # id,counter,title,tag,value,text
  @uploaded_images = []
  @all_images.each_with_index do |image, index|
    link_url = image['value']
    basename = File.basename(link_url)
    filepath = "#{IMAGES}/#{basename}"
    if File.exist?(filepath)
      wiki_image_id = image['id']
      confluence_page = @created_pages.detect { |page| page['page_id'] == wiki_image_id }
      if confluence_page
        confluence_page_id = confluence_page['id']
        result = confluence_create_attachment(confluence_page_id, filepath, index + 1, total_images)
        @uploaded_images << {
          result: result ? 'OK' : 'NOK',
          confluence_image_id: result ? result['results'][0]['id'] : nil,
          wiki_image_id: wiki_image_id,
          confluence_page_id: confluence_page_id,
          link_url: link_url
        }
      else
        puts "Cannot find confluence_id for wiki_id='#{wiki_image_id}'"
      end
    else
      puts "Cannot find image='#{filepath}'"
    end
  end

  puts
  write_csv_file(UPLOADED_IMAGES_CSV, @uploaded_images)
end

# confluence_page_id to wiki_page_id converter
@c_to_w_page_id = {}
@w_to_c_page_id = {}
# result,page_id,id,offset,title,author,created_at,body,error
csv_to_array(CREATED_PAGES_CSV).each do |page|
  @c_to_w_page_id[page['id']] = page['page_id']
  @w_to_c_page_id[page['page_id']] = page['id']
end

# Convert all <img src="link_url" ... > to
# <ac:image ac:height="250"><ri:attachment ri:filename="{image}" ri:version-at-save="1" /></ac:image>
def update_all_image_links
  confluence_page_ids = {}
  # result,confluence_image_id,wiki_image_id,confluence_page_id,link_url
  @uploaded_images = csv_to_array(UPLOADED_IMAGES_CSV)
  @uploaded_images.each do |image|
    confluence_page_id = image['confluence_page_id']
    confluence_page_ids[confluence_page_id] = [] unless confluence_page_ids[confluence_page_id]
    confluence_image_id = image['confluence_image_id']
    link_url = image['link_url']
    confluence_page_ids[confluence_page_id] << { confluence_image_id: confluence_image_id, link_url: link_url }
  end

  total = confluence_page_ids.length
  counter = 1
  confluence_page_ids.each do |c_page_id, images|
    w_page_id = @c_to_w_page_id[c_page_id]
    if w_page_id.nil?
      puts "confluence_page_id='#{c_page_id}' => NOK (unknown w_page_id)"
      next
    end

    # id,page_name,contents,status,version,position,wiki_format,change_comment,parent_id,space_id,user_id,created_at,updated_at
    w_page = csv_to_array(WIKI_FIXED_CSV).detect { |page| page['id'] == w_page_id }
    if w_page.nil?
      puts "confluence_page_id='#{c_page_id}' wiki_page_id='#{w_page_id}' => NOK (unknown w_page)"
      next
    end

    puts "confluence_page_id='#{c_page_id}' wiki_page_id='#{w_page_id}' => OK"

    content = confluence_get_content(c_page_id, counter, total)

    images.each do |image|
      confluence_image_id = image[:confluence_image_id]
      link_url = image[:link_url]

      if content.match?(/<img(.*)? src="#{link_url}"([^>]*?)>/)
        basename = File.basename(link_url)
        content.sub!(/<img(.*)? src="#{link_url}"([^>]*?)>/, "<ac:image ac:height=\"250\"><ri:attachment ri:filename=\"#{basename}\" ri:version-at-save=\"1\" /></ac:image>")
        res = 'OK'
      else
        res = 'NOK'
      end
      puts "* confluence_image_id='#{confluence_image_id}' link_url='#{link_url}' => #{res}"
    end
    counter += 1
  end
end

def update_all_page_links
  confluence_page_ids = {}
  # id,counter,title,tag,value,text
  @all_wikis.each do |wiki|
    wiki_page_id = wiki['id']
    confluence_page_id = @w_to_c_page_id[wiki_page_id]
    confluence_page_ids[confluence_page_id] = [] unless confluence_page_ids[confluence_page_id]
    link_url = image['link_url']
    wiki_page_id = File.basename(link_url)
    external_page_id = w_to_c_page_id[wiki_page_id]
    confluence_page_ids[confluence_page_id] << { external_page_id: external_page_id, link_url: link_url }
  end

  # Convert all <a href="...">(title)</a> to
  # <ac:link><ri:page ri:content-title="(title)" ri:version-at-save="1" /></ac:link>
  confluence_page_ids.each do |c_page_id, pages|

  end
end

#
# upload_all_pages

#
# upload_all_images

#
update_all_image_links

# update_all_page_links

#
# update_all_document_links

#
# convert_all_ticket_links

puts "\nDone\n"
