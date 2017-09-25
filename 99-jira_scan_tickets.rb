# frozen_string_literal: true

load './lib/common.rb'

@tickets_jira = csv_to_array("#{OUTPUT_DIR_JIRA}/jira-tickets.csv")

@tickets_jira.each do |ticket|
  description = ticket['description']
  lines = description.split("\n")
  lines.shift
  lines.each do |line|
    puts "#{ticket['jira_ticket_key']} #{line}" if /europeana\-[^na].*\/ticket/.match(line)
  end
end

# Collections
# EC-152 figure out a method for deploying to production that will not interrupt production service. see this post for [one possible approach|https://europeanadev.assembla.com/spaces/europeana-npc/tickets/91-create-jenkins-build-jobs?comment=700005603#comment:700005603].
# EC-222 Context for the request is at https://europeanadev.assembla.com/spaces/europeana-npc/tickets/173-search-result-list-implementation--iteration-2?comment=726274553#comment:726274553
# EC-278 See point 1 in Richard's comment to this tasks mother story, https://europeanadev.assembla.com/spaces/europeana-npc/tickets/226-automatically-pull-in-latest-blog-posts-to-portal-and-channel-landing-page?comment=757521063#comment:757521063
# EC-313 	the load-on-demand behaviour that we began to implement for the [map|https://europeanadev.assembla.com/spaces/europeana-npc/tickets/172-item-display-implementation--iteration-2] should continue to work as before
# EC-522 The second IIIF example implemented in https://europeanadev.assembla.com/spaces/europeana-npc/tickets/424-implement-leaflet-based-iiif-viewer?comment=800546913#comment:800546913 is incorrect. It matches the wrong item with the wrong IIIF-manifest. Its IIIF-manifest must be removed.
# EC-872 We need a more elegant solution than the one implemented in EC-796 for the reasons listed by Richard here https://europeanadev.assembla.com/spaces/europeana-npc/tickets/758/details?comment=879210213
# EC-1154 * ✔ EC-1031: Disable the [custom facets|https://europeanadev.assembla.com/spaces/europeana-npc/tickets/994/details?comment=937014943]
# EC-1291 From iteration 3 of landingpage improvements: https://www.assembla.com/spaces/europeana-npc/tickets/new_cardwall?tab=activity#ticket:1150
# EC-1292 Iteration 3: https://www.assembla.com/spaces/europeana-npc/tickets/new_cardwall?tab=activity#ticket:1197
# EC-1331 See: https://app.assembla.com/spaces/europeana-npc/tickets/1203/details?comment=995403203
# EC-1581 The two titles are not separated as we had agreed for EC-445: https://europeanadev.assembla.com/spaces/europeana-npc/tickets/404/details?comment=858350753
# EC-1646 The solution used [here|https://europeanadev.assembla.com/spaces/europeana-npc/tickets/1518/] follows the technique used for the Europeana logo: it uses a background image defined in the CSS.  This works because relative paths in CSS are resolved relative to the stylesheet, not the app server, and so the div added in the CMS with the class "opus-img" corresponds to a CSS rule that gives it the background image "europeana_opus.png"
# EC-1887 See ticket [EC-1296|https://europeanadev.assembla.com/spaces/europeana-npc/tickets/1259-end-user-blog-migration/details] for reference
# EC-1888 This epic is based on the conversations in ticket [1426|https://europeanadev.assembla.com/spaces/europeana-npc/tickets/1798-spike--editorially-created-image-galleries/details|1798]] and the designs provided in ticket [[url:https://europeanadev.assembla.com/spaces/europeana-npc/tickets/1426-ui-visual-design-of-a-gallery-feature/details]
# EC-1900 # See https://europeanadev.assembla.com/spaces/europeana-npc/tickets/1864/details?comment=1132426353
# EC-1916 All the exhibitions links redirected to the corresponding new exhibitions according to the google doc from ticket [EC-1794|https://europeanadev.assembla.com/spaces/europeana-npc/tickets/new_cardwall#ticket:1757]
# EC-1924 For video and audio we use videojs 4.12.  This is incompatible with the [wavesurfer library we want to use|https://europeanadev.assembla.com/spaces/europeana-npc/tickets/new_cardwall#ticket:1724] so we need to start using a version > 5.
# EC-1953 To support front-end template as referred at https://europeanadev.assembla.com/spaces/europeana-npc/tickets/1867-display-galleries-in-europeana-collections/details
# EC-1955 Context: https://europeanadev.assembla.com/spaces/europeana-npc/tickets/1905/details?comment=1143553133
# EC-2071 See https://app.assembla.com/spaces/europeana-npc/tickets/2024/details?comment=1177530233 for context.
# EC-2133 https://europeanadev.assembla.com/spaces/europeana-npc/tickets/1997/details?comment=1192636403
# EC-2133 https://europeanadev.assembla.com/spaces/europeana-npc/tickets/1997/details?comment=1192670343
# EC-2133 https://europeanadev.assembla.com/spaces/europeana-npc/tickets/1997/details?comment=1192685123
# EC-2154 Assembla SPIKE ticket: https://app.assembla.com/spaces/europeana-npc/tickets/1804
# EC-2205  - In the license links in the dropdown, there should only be the options as specified by Maggy (https://europeanadev.assembla.com/spaces/europeana-npc/tickets/2184/details?comment=1213723653)
# EC-2220 Relates to work done in previous ticket here: https://app.assembla.com/spaces/europeana-npc/tickets/2136/details?comment=1210160403
# EC-2285 [[url:https://europeanadev.assembla.com/spaces/europeana-npc/tickets/2145/details?comment=1226159003|[~DavidHaskiya] or, we could blacklist these by dataset ID, using non-SSL for their record pages and SSL for everything else, which would be very simple to achieve in Apache alone.
# EC-2286 https://europeanadev.assembla.com/spaces/europeana-npc/tickets/new_cardwall#ticket:2217
# EC-2286 [[url:https://europeanadev.assembla.com/spaces/europeana-npc/tickets/new_cardwall#ticket:2217|[~ash.marriott] there is not much more to say about this than the above, but we should create a follow-up task to implement an adaptation on the Collections side so that the API change (removing Neo4J dependency from calls to the record endpoint) deployment can be unblocked. Given that we do have this inter-team/product blocker, I would be inclined to include this in the next sprint.
# EC-2306  - - no errors such as the on you noticed yourself for dc:publisher (https://europeanadev.assembla.com/spaces/europeana-npc/tickets/2152-bug--publisher-metadata-hyperlink-is-not-working/details)
# EC-2349 As identified by [~kgish] https://europeanadev.assembla.com/spaces/europeana-npc/tickets/2254/details?comment=1259436103 there are various uses of page_title, these .rb templates should use page_content_heading and only application_view.rb shoul use page_title
# EC-2394 This will be a full migration from the [spike|https://www.assembla.com|Assembla]] ticketing tool to the [https://www.atlassian.com/software/jira|Jira|https://www.atlassian.com/software/jira|Jira] issue tracking tool and is based on the findings in the earlier [[url:https://app.assembla.com/spaces/europeana-npc/tickets/new_cardwall#ticket:2352].

# APIs links
# EC-951 See [this|https://www.assembla.com/spaces/europeana-apis/tickets/new_cardwall#ticket:9] ticket about restoring the OpenSearch functionality for Europeana.
# EC-1001 See: https://www.assembla.com/spaces/europeana-apis/tickets/109-epic--dynamic-hit-highlighting/details?tab=activity
# EC-1107 Background: https://europeanadev.assembla.com/spaces/europeana-apis/tickets/35-spike--bi-directional-reference-links-between-europeana-and-wikidata/details
# EC-1342 Background, context: https://europeanadev.assembla.com/spaces/europeana-apis/tickets/172/details?comment=999255843
# EC-1377 See: https://app.assembla.com/spaces/europeana-apis/tickets/realtime_cardwall?ticket=228
# EC-1511 The first thing we could do is to get annotations to display in Europeana. The [Wikidata experiment|https://europeanadev.assembla.com/spaces/europeana-apis/tickets/35/details] seems the perfect candidate for this. No additional work for this is needed on the Annotations API and the benefit is that Collections can already start exploring how to connect with a different API and pull in annotations. We probably shouldn't label them as such as that would imply to users that they can add annotations themselves.
# EC-1873 As discussed here: https://europeanadev.assembla.com/spaces/europeana-apis/tickets/437-entity-api--improve-(production)-paths/details
# EC-1889 In https://europeanadev.assembla.com/spaces/europeana-apis/tickets/344 we implemented the import from Commons of links to media files there from our objects. But these links are not displayed to the user. This should be fixed.
# EC-1938 The issue is that the Annotations API has just implemented the standard profile (see https://europeanadev.assembla.com/spaces/europeana-apis/tickets/65) and made that its default profile, which Europeana Radio is not capable of parsing. As the production Annotations API will not yet accept the profile parameter, even just to ignore it, it is necessary to make Europeana Radio capable of parsing both the minimal and standard profiles, whichever happens to be returned by the Annotations API it is connected to by default.
# EC-1950 * Items to Exhibitions, see EC-1591 and https://europeanadev.assembla.com/spaces/europeana-apis/tickets/245
# EC-1991 https://europeanadev.assembla.com/spaces/europeana-apis/tickets/245
# EC-1994 * Fix formal errors in the sitemap, e.g. broken links ([API ticket 605|https://europeanadev.assembla.com/spaces/europeana-apis/tickets/605]) and blocked links (#2150)
# EC-1994 * Ensure we have timestamps for last updated in the sitemap ([API ticket 631|https://europeanadev.assembla.com/spaces/europeana-apis/tickets/631])
# EC-1994 * Test a smaller sitemap but with the best of our content ([ticket 624|https://europeanadev.assembla.com/spaces/europeana-apis/tickets/475|API ticket 475]] and [[url:https://europeanadev.assembla.com/spaces/europeana-apis/tickets/624])
# EC-2047 They therefore need to be adapted to handle this scenario, before the [Annotations API change|https://app.assembla.com/spaces/europeana-apis/tickets/524] makes it to production.
# EC-2144 API ticket: https://app.assembla.com/spaces/europeana-apis/tickets/realtime_cardwall?ticket=526
# EC-2145 API ticket: https://app.assembla.com/spaces/europeana-apis/tickets/realtime_cardwall?ticket=526
# EC-2238 To investigate what the impact of the changes from https://app.assembla.com/spaces/europeana-apis/tickets/640
# EC-2311 The Record API has been adapted to issue 301 redirects for records whose IDs have changed: https://europeanadev.assembla.com/spaces/europeana-apis/tickets/662
# EC-2373 The GET method of the Entity API has been updated to expose the Wikimedia Commons link in the response, see ticket [API ticket 755|https://app.assembla.com/spaces/europeana-apis/tickets/755]. This change implies that the value of the depiction field is no longer a string (URI) but a structure made out of an "id" and "source" fields.
# EC-2374 We have recently noticed that the Entity API had not been updated following an update of spec that was done a while ago, see [API ticket 760|https://app.assembla.com/spaces/europeana-apis/tickets/760]. In particular, the field "contains" and "totalItems" were not changed to respectively "items" and "total".

# 1914-1918
# EC-50 Compare with https://europeanadev.assembla.com/spaces/europeana-1914-1918/tickets/366
# EC-160 https://europeanadev.assembla.com/spaces/europeana-1914-1918/tickets/8
# EC-160 https://europeanadev.assembla.com/spaces/europeana-1914-1918/tickets/9
# EC-171 * https://europeanadev.assembla.com/spaces/europeana-1914-1918/tickets/510
# EC-171 * https://europeanadev.assembla.com/spaces/europeana-1914-1918/tickets/366

# Infrastructure
# EC-2379 Follows ticket 215: https://europeanadev.assembla.com/spaces/europeana-infrastructure/tickets/215-upgrade-cf-cli-on-jenkins-nodes/details

# Professional
# EC-1970 Also related, see the Pro ticket re RSS feeds and JSON API in Bolt CMS: https://europeanadev.assembla.com/spaces/europeana-professional/tickets/633

# Ingestion
# EC-164 To create copy fields that allow us for truly querying for exact matches on title, who, what and other important fields, see https://europeanadev.assembla.com/spaces/europeana-ingestion/tickets/1619-improve-relevancy-of-results-for-the-prototype-entity-autocompletion-api?comment=711706813#comment:711706813
# EC-686 https://europeanadev.assembla.com/spaces/europeana-ingestion/tickets/1666-entities-api-design#/activity/ticket:

# r-d
# EC-1948 Presently, there is no way of identifying the user session within the logs that are stored in ELK, which is crucial to identify user search patterns. See ticket: https://europeanadev.assembla.com/spaces/europeana-r-d/tickets/13

# creative
# EC-1950 * Revisit the mass-tagging and search macro features ideas for channels/thematic collections, https://europeanadev.assembla.com/spaces/europeana-creative/tickets/45 and in greate detail https://docs.google.com/document/d/15nqqs7M9V25iku9NsiEfXl-vJpWh31LmyaYVA__cvho/edit
