# frozen_string_literal: true

load './lib/common.rb'

# id,page_name,contents,status,version,position,wiki_format,change_comment,parent_id,space_id,user_id,created_at,updated_at
wiki_assembla_csv = "#{OUTPUT_DIR_ASSEMBLA}/wiki-pages.csv"
@wiki_assembla = csv_to_array(wiki_assembla_csv)

pages = {}

@wiki_assembla.each do |wiki|
  id = wiki['id']
  if pages[id]
    puts "Detected duplicate id='#{id}' => SKIP"
  else
    pages[id] = {
        page: wiki,
        parent: @wiki_assembla.find { |page| page['id'] === wiki['parent_id'] },
        children: []
    }
  end
end

pages.each do |id, value|
  parent = value[:parent]
  next unless parent
  parent_id = parent['id']
  page = pages[parent_id]
  if page
    page[:children] << pages[id]
  else
    puts "Cannot find page with parent_id='#{parent_id}'"
  end
end

puts '---'

pages.each do |id, value|
  parent = value[:parent]
  next if parent
  children = pages[id][:children]
  count = children.length
  if count.positive?
    children_ids = children.map { |child| child[:page]['id']}
    puts "id='#{id}' children='#{count}' ids='#{children_ids.join(',')}'"
  else
    puts "id='#{id}' no children"
  end
end

puts '---'

pages.each do |id, value|
  parent = value[:parent]
  next unless parent
  parent_id = parent['id']
  children = pages[id][:children]
  count = children.length
  if count.positive?
    children_ids = children.map { |child| child[:page]['id']}
    puts "id='#{id}' parent_id='#{parent_id}' children='#{count}' ids='#{children_ids.join(',')}'"
  else
    puts "id='#{id}' parent_id='#{parent_id}' no children"
  end
end

puts '---'

puts "Done!"