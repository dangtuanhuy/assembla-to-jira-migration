# frozen_string_literal: true

load './lib/common.rb'

write_csv_file("#{OUTPUT_DIR_JIRA}/jira-roles.csv", jira_get_roles)
