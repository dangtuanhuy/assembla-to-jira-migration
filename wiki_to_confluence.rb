# frozen_string_literal: true

load './lib/common.rb'

def abort(message)
  puts "ERROR: #{message} => EXIT"
  exit
end

# id,page_name,contents,status,version,position,wiki_format,change_comment,parent_id,space_id,user_id,created_at,updated_at
wiki_assembla_csv = "#{OUTPUT_DIR_ASSEMBLA}/wiki-pages.csv"
@wiki_assembla = csv_to_array(wiki_assembla_csv)

@pages = {}

puts "\n--- Wiki pages: #{@wiki_assembla.length} ---\n"

@wiki_assembla.each do |wiki|
  id = wiki['id']
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
  created_at = page['created_at'].sub(/\.[^.]*$/, '')
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

puts "\nDone\n"
