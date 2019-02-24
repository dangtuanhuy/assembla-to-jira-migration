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

# wiki_assembla => id,page_name,contents,status,version,position,wiki_format,change_comment,parent_id,space_id,
# user_id,created_at,updated_at
wiki_assembla_csv = "#{OUTPUT_DIR_ASSEMBLA}/wiki-pages.csv"
@wiki_assembla = csv_to_array(wiki_assembla_csv)

# id,login,name,picture,email,organization,phone
users_assembla_csv = "#{OUTPUT_DIR_ASSEMBLA}/users.csv"
@users_assembla = csv_to_array(users_assembla_csv)

@pages = {}
@created_pages = []

puts "\n--- Wiki pages: #{@wiki_assembla.length} ---\n"

@wiki_assembla.each do |wiki|
  id = wiki['id']
  wiki['page_name'].tr!('_', ' ')
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

      text = m[1]
      counter += 1
      links << {
        id: id,
        counter: counter,
        title: title,
        tag: 'anchor',
        value: value,
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

def create_page_item(id, offset)
  pages_id = @pages[id]
  page = pages_id[:page]
  title = page['page_name']
  parent_id = page['parent_id']
  user_id = page['user_id']
  user = @users_assembla.detect { |u| u['id'] == user_id }
  author = user ? user['name'] : ''
  created_at = format_created_at(page['created_at'])
  body = page['contents']

  result = confluence_create_page(@space['key'], title, body, parent_id)
  @created_pages <<
    if result
      {
        result: 'OK',
        id: result['id'],
        offset: offset.join('-'),
        title: title,
        author: author,
        created_at: created_at
      }
    else
      {
        result: 'NOK',
        id: 0,
        offset: offset.join('-'),
        title: title,
        author: author,
        created_at: created_at
      }
    end
end

def download_image(url, counter, total)
  filepath = "#{IMAGES}/#{File.basename(url)}"
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
  links = csv_to_array(LINKS_CSV)
  images = links.select { |link| link['tag'] == 'image' }
  total = images.length
  puts "\nDownloading #{total} images"
  images.each_with_index do |image, index|
    download_image(image['value'], index + 1, total)
  end
  puts "Done!\n"
end

# get_all_links
download_all_images
exit

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


count = 0
@parent_pages.each do |id, _|
  create_page_item(id, [count])
  count += 1
end

puts "\nDone\n"
