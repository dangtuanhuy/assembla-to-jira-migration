# frozen_string_literal: true

load './lib/common.rb'

[
  { name: 'issue-types', fn: jira_get_issue_types },
  { name: 'priorities',  fn: jira_get_priorities  },
  { name: 'resolutions', fn: jira_get_resolutions },
  { name: 'roles',       fn: jira_get_roles       },
  { name: 'statuses',    fn: jira_get_statuses    },
  { name: 'projects',    fn: jira_get_projects    }
].each do |item|
  write_csv_file("#{OUTPUT_DIR_JIRA}/jira-#{item[:name]}.csv", item[:fn])
end
