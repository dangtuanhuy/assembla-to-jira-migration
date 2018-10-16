# frozen_string_literal: true

load './lib/common.rb'

def jira_get_group(group_name)
  result = []
  batchsize = 50
  startAt = 0
  processing = true
  while processing
    url = "#{JIRA_API_HOST}/group/member?groupname=#{group_name}&includeInactiveUsers=true&startAt=#{startAt}&maxResults=#{batchsize}"
    begin
      response = RestClient::Request.execute(method: :get, url: url, headers: JIRA_HEADERS_ADMIN)
      body = JSON.parse(response.body)
      users = body['values']
      puts "GET #{url} => OK (#{users.length})"
      users.each do |user|
        result << user
      end
      processing = !body['isLast']
    rescue => e
      puts "GET #{url} => NOK (#{e.message})"
      result = []
      processing = false
    end
    startAt = startAt + batchsize if processing
  end
  result.select { |user| !/^addon_/.match(user['name'])}
end

results = jira_get_group('jira-core-users')

results.each { |result| puts result['name']}