# frozen_string_literal: true

load './lib/common.rb'

write_csv_file("#{OUTPUT_DIR_JIRA}/jira-issue-types.csv", jira_get_issue_types)
