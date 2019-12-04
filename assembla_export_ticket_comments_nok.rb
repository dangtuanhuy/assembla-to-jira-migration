# frozen_string_literal: true

load './lib/common.rb'

tickets = %w{
16,1
17,1
20,1
36,1
37,1
41,1
44,1
49,1
51,1
56,1
60,1
77,1
88,1
94,2
95,1
102,1
104,1
112,1
113,1
116,1
119,1
120,1
121,1
127,1
133,1
135,1
139,1
141,1
144,2
145,1
148,1
159,1
162,1
164,1
166,1
175,1
180,2
182,1
184,1
199,1
202,1
203,1
206,1
207,1
211,1
214,1
215,1
216,1
219,1
220,1
223,1
232,1
234,1
240,1
244,1
248,1
251,1
252,1
253,1
260,1
262,1
263,1
265,1
274,1
276,1
279,1
280,1
282,1
283,1
291,1
292,1
307,1
317,1
322,1
323,1
326,1
334,1
336,1
342,1
343,1
344,1
345,1
347,1
352,1
354,1
355,1
356,1
357,1
358,1
359,1
360,1
361,1
363,1
367,1
370,1
372,1
373,1
374,1
376,1
380,1
392,1
394,1
402,1
403,1
404,4
405,1
406,1
408,1
409,1
410,1
418,1
423,1
433,1
437,1
438,1
440,1
445,1
450,1
451,1
452,1
453,1
455,1
458,22
462,1
471,1
475,1
476,1
478,1
484,1
487,1
488,1
489,1
490,1
491,1
492,1
496,1
498,1
499,1
500,1
502,1
506,1
508,1
510,1
511,1
514,1
516,1
523,1
526,1
536,4
537,1
549,1
552,1
562,1
568,1
579,1
581,1
583,1
587,10
591,1
603,1
604,1
605,1
606,1
610,1
611,1
616,1
619,1
621,1
622,2
623,1
626,1
628,5
629,1
630,1
631,1
632,1
633,1
636,1
654,1
655,1
657,1
660,1
663,1
665,1
667,1
672,1
677,2
678,2
703,1
704,1
710,1
720,1
730,1
747,1
751,1
755,1
787,1
789,3
790,2
791,2
793,2
813,9
}

def http_request(url)
  response = nil
  error = nil
  begin
    response = RestClient::Request.execute(method: :get, url: url, headers: ASSEMBLA_HEADERS)
    count = get_response_count(response)
    puts "GET #{url} => OK (#{count})"
  rescue => e
    if e.class == RestClient::NotFound && e.response.match?(/Tool not found/i)
      puts "GET #{url} => OK (0)"
    else
      error = "#{e.message}"
      puts "GET #{url} => NOK (#{e.message})"
    end
  end
  return response, error
end

def get_response_count(response)
  return 0 if response.nil? || !response.is_a?(String) || response.length.zero?
  begin
    json = JSON.parse(response)
    return 0 unless json.is_a?(Array)
    return json.length
  rescue
    return 0
  end
end

def get_ticket_comments(space_id, ticket_number)
  url = "#{ASSEMBLA_API_HOST}/spaces/#{space_id}/tickets/#{ticket_number}/ticket_comments?per_page=1"
  page = 1
  results = []
  in_progress = true
  while in_progress
    full_url = url
    full_url += "&page=#{page}"
    response, error = http_request(full_url)
    if error
      page += 1
    else
      count = get_response_count(response)
      if count == 0
        in_progress = false
      else
        JSON.parse(response.body).each do |result|
          results << result
        end
        page += 1
      end
    end
    results
  end
end

space = get_space(ASSEMBLA_SPACE)

all_results = []
tickets.each do |ticket|
  number, page = ticket.split(',')
  results = get_ticket_comments(space['id'], number)
  all_results << results if results
end

