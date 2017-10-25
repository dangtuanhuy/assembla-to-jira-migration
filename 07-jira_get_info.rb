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
  name = item[:name]
  fn = item[:fn]
  filename = "#{OUTPUT_DIR_JIRA}/jira-#{name}.csv"
  write_csv_file(filename, fn)
  if name == 'issue-types'
    missing = []
    issue_types = csv_to_array(filename)
    ASSEMBLA_TYPES_EXTRA.each do |name|
      missing << name unless issue_types.detect { |t| name.casecmp(t['name']) == 0 }
    end
    if missing.length.positive?
      puts "\nMissing issue types:"
      missing.each do |m|
        puts "* #{m.capitalize}"
      end
      goodbye('You MUST first create issue type(s) and assign to screens (see README.md). Afterwards please re-run this script before continuing.')
    end
  end
end

