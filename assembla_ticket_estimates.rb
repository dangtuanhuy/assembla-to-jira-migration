# frozen_string_literal: true

load './lib/common.rb'

# --- ASSEMBLA Tickets --- #

# id,number,summary,description,priority,completed_date,component_id,created_on,permission_type,importance,is_story,
# milestone_id,notification_list,space_id,state,status,story_importance,updated_at,working_hours,estimate,
# total_estimate,total_invested_hours,total_working_hours,assigned_to_id,reporter_id,custom_fields,hierarchy_type,
# due_date,assigned_to_name,picture_url
tickets_assembla_csv = "#{OUTPUT_DIR_ASSEMBLA}/tickets.csv"
@tickets_assembla = csv_to_array(tickets_assembla_csv)

@tickets_assembla.each do |ticket|
  number = ticket['number'].to_i
  estimate = ticket['estimate'].to_i
  total_estimate = ticket['total_estimate'].to_i
  next if estimate.zero? && total_estimate.zero?
  if estimate != total_estimate
    puts "number=#{number} estimate='#{estimate}' total_estimate='#{total_estimate}'"
  else
    puts "number=#{number} estimate='#{estimate}'"
  end
end
