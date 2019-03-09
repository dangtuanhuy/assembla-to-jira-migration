# frozen_string_literal: true

def percentage(counter, total)
  "#{counter.to_s.rjust(total.to_s.length, ' ')}/#{total} #{(counter * 100 / total).floor.to_s.rjust(3, ' ')}%"
end

def confluence_get_spaces
  url = "#{API}/space"
  results = nil
  begin
    response = RestClient::Request.execute(method: :get, url: url, headers: HEADERS)
    body = JSON.parse(response.body)
    results = body['results']
    puts "GET url='#{url}' => OK"
  rescue => e
    error = e.response ? JSON.parse(e.response) : e
    puts "GET url='#{url}' => NOK error='#{error}'"
  end
  results
end

# id, key, name, type, status
def confluence_get_space(name)
  confluence_get_spaces.detect { |space| space['name'] == name }
end

@space = confluence_get_space(SPACE)
if @space
  puts "Found space='#{SPACE}' => OK"
else
  puts "Cannot find space='#{SPACE}' => exit"
  exit
end

# GET wiki/rest/api/content/{id}?expand=body.storage
# content = result['body']['storage']['value']
def confluence_get_content(id, counter, total)
  content = nil
  url = "#{API}/content/#{id}?expand=body.storage"
  pct = percentage(counter, total)
  begin
    response = RestClient::Request.execute(method: :get, url: url, headers: HEADERS)
    result = JSON.parse(response.body)
    content = result['body']['storage']['value']
    puts "#{pct} GET url='#{url}' => OK"
  rescue => e
    error = e.response ? JSON.parse(e.response) : e
    puts "#{pct} GET url='#{url}' => NOK error='#{error}'"
  end
  content
end

# GET wiki/rest/api/content/{id}?expand=version
def confluence_get_version(id)
  result = nil
  url = "#{API}/content/#{id}?expand=version"
  begin
    response = RestClient::Request.execute(method: :get, url: url, headers: HEADERS)
    result = JSON.parse(response.body)
    puts "GET url='#{url}' => OK"
  rescue => e
    error = e.response ? JSON.parse(e.response) : e
    puts "GET url='#{url}' => NOK error='#{error}'"
  end
  result
end

# POST wiki/rest/api/content
# {
#   "type": "page",
#   "title": <TITLE>,
#   "space": { "key": <KEY> },
#   "ancestors": [
#     {
#       "id": @parent_id
#     }
#   ],
#   "body": {
#     "storage": {
#       "value": <CONTENT>,
#       "representation": "storage"
#     }
#   }
# }
#
def confluence_create_page(key, title, prefix, body, parent_id, counter, total)
  result = nil
  error = nil
  error_message = nil
  content = "#{prefix}#{body}"
  retries = 0
  while result.nil? && retries < 3
    if retries == 1
      macro = "<ac:structured-macro ac:name=\"code\" ac:schema-version=\"1\" ac:macro-id=\"5920cc53-cd45-4ee4-8012-5c987c6e0c75\"><ac:plain-text-body><![CDATA[#{body}]]></ac:plain-text-body></ac:structured-macro>"
      content = "#{prefix}<p>#{CGI.escapeHTML(error_message)}</p>#{macro}"
    elsif retries == 2
      content = "#{prefix}<p>#{error_message}</p>"
    end

    payload = {
      "type": 'page',
      "title": title,
      "space": { "key": key },
      "body": {
        "storage": {
          "value": content,
          "representation": 'storage'
        }
      }
    }

    if parent_id
      payload['ancestors'] = [{ "id": parent_id }]
    end

    pct = percentage(counter, total)
    payload = payload.to_json
    url = "#{API}/content"
    begin
      response = RestClient::Request.execute(method: :post, url: url, payload: payload, headers: HEADERS)
      result = JSON.parse(response.body)
      puts "#{pct} POST url='#{url}' title='#{title}' => OK"
    rescue RestClient::BadRequest => e
      if e.response
        error = JSON.parse(e.response)
        if error['message'].start_with?('Error parsing xhtml')
          msg = retries < 2 ? "[RETRY ##{retries + 1}] " : ''
          error_message = error['message']
          puts "#{pct} POST url='#{url}' title='#{title}' => NOK #{msg}error='#{error_message}'"
          retries += 1
        else
          puts "#{pct} POST url='#{url}' title='#{title}' => NOK error='#{error}'"
          retries = 100
        end
      else
        puts "#{pct} POST url='#{url}' title='#{title}' => NOK error='#{e}'"
        retries = 100
      end
    rescue => e
      error = e.response ? JSON.parse(e.response) : e
      puts "#{pct} POST url='#{url}' title='#{title}' => NOK error='#{error}'"
      retries = 100
    end
  end

  [result, error]
end

# PUT wiki/rest/api/content/{id}
# {
#   "type": "page",
#   "space": { "key": <KEY> },
#   "body": {
#     "storage": {
#       "value": <CONTENT>,
#       "representation": "storage"
#     }
#   }
# }
#
def confluence_update_page(key, id, title, content, counter, total)

  result = nil
  result_get_version = confluence_get_version(id)
  return nil unless result_get_version

  version = result_get_version['version']['number']

  pct = percentage(counter, total)
  payload = {
    "title": title,
    "type": 'page',
    "space": { "key": key },
    "version": { "number": version + 1 },
    "body": {
      "storage": {
        "value": content,
        "representation": 'storage'
      }
    }
  }
  payload = payload.to_json
  url = "#{API}/content/#{id}"
  begin
    response = RestClient::Request.execute(method: :put, url: url, payload: payload, headers: HEADERS)
    result = JSON.parse(response.body)
    puts "#{pct} PUT url='#{url}' id='#{id}' => OK"
  rescue => e
    error = JSON.parse(e.response)
    puts "#{pct} PUT url='#{url}' id='#{id}' => NOK error='#{error}'"
  end
  result
end

# POST /wiki/rest/api/content/{id}/child/attachment
# {
#   multipart: true,
#   file: @file.txt
# }
def confluence_create_attachment(page_id, filepath, counter, total)
  result = nil
  pct = percentage(counter, total)
  payload =
    {
      multipart: true,
      file: File.new(filepath, 'rb')
    }
  url = "#{API}/content/#{page_id}/child/attachment"
  headers = {
    'Authorization': "Basic #{Base64.encode64("#{EMAIL}:#{PASSWORD}")}",
    'Content-Type': 'application/json; charset=utf-8',
    'Accept': 'application/json',
    'X-Atlassian-Token': 'nocheck'
  }
  begin
    response = RestClient::Request.execute(method: :post, url: url, payload: payload, headers: headers)
    result = JSON.parse(response.body)
    puts "#{pct} POST url='#{url}' page_id='#{page_id}' filepath='#{filepath}' => OK"
  rescue => e
    error = JSON.parse(e.response)
    puts "#{pct} POST url='#{url}' page_id='#{page_id}' filepath='#{filepath}' => NOK error='#{error}'"
  end
  result
end
