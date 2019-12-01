# frozen_string_literal: true

load './lib/common.rb'

jira_get_project_by_name(JIRA_API_PROJECT_NAME) || jira_create_project(JIRA_API_PROJECT_NAME, JIRA_PROJECT_KEY, JIRA_API_PROJECT_TYPE)
