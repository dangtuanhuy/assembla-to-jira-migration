# frozen_string_literal: true

load './lib/common.rb'

tickets_assembla_csv = "#{OUTPUT_DIR_ASSEMBLA}/tickets.csv"
@tickets_assembla = csv_to_array(tickets_assembla_csv)

file_csv = "#{OUTPUT_DIR_ASSEMBLA}/tickets-custom-fields.csv"
@tickets_custom_fields_assembla = csv_to_array(file_csv)

title_2_type = {}
@tickets_custom_fields_assembla.each do |item|
  title_2_type[item['title']] = item['type']
end

puts "Tickets: #{@tickets_assembla.length}"

# Custom fields
@custom_fields = {}
@tickets_assembla.each do |ticket|
  c_fields = ticket['custom_fields']
  next if c_fields&.empty?
  fields = JSON.parse(c_fields.gsub(/=>/, ': '))
  fields.each do |k, v|
    @custom_fields[k] = [] unless @custom_fields[k]
    @custom_fields[k] << v unless v&.empty? || @custom_fields[k].include?(v)
  end
end

puts "\nTotal custom fields: #{@custom_fields.keys.length}"

@custom_fields.keys.each do |k|
  custom_field = @custom_fields[k]
  puts "\nTotal #{k}: #{custom_field.length}"
  custom_field = title_2_type[k] == 'Numeric' ? custom_field.sort_by(&:to_f) : custom_field.sort
  custom_field.each do |name|
    puts "* #{name}"
  end
end