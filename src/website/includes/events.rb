##
# Define all of the methods for generating "Events" divs.
# Primarily this file will perform two actions
#   * Generate the "Events" block for the splash page
#   * Generate the full page view of events, with pager
#

# NOTE: Namespacing was not done for this file as we were unsure of the
#       module names you would like us to use for this type of definition.

class Events
  # Constants
  BLOCK_LIST_LEN = 4
  PAGE_LIST_LEN = 10

  ##
  # Generate Events block for the splash page (50% column)
  def self.getEventsBlock(server)
    return <<-HTML
      <div id='events' class='highlight'>
        <div class="title">
          <i class="fa fa-calendar"></i><a href="#{server.context}/Events">Events</a>
        </div>
        #{eventsToHtml(getEvents(server), 0, BLOCK_LIST_LEN)}
        <div class='more-link'><a href='#{server.context}/Events'>more</a></div>
      </div>
    HTML
  end

  ##
  # Generate full Events page content, with pager.
  def self.getEventsPage(server, page = 0)
    startEvent = page * PAGE_LIST_LEN

    # Build the simple pager
    pager = ""
    list = getEvents(server)
    if (page > 0)
      pager << "<a href='?page=#{page - 1}'><i class='fa fa-angle-double-left'></i> Previous Page</a> "
    end
    if (list.count > (page + 1) * PAGE_LIST_LEN)
      pager << "<a href='?page=#{page + 1}'>Next Page <i class='fa fa-angle-double-right'></i></a>"
    end

    # Build the HTML
    html = <<-HTML
    <div id='events'>
      <div class="title">
        <i class="fa fa-calendar"></i>Events
      </div>
      #{eventsToHtml(list, startEvent, PAGE_LIST_LEN)}
      <div class='pager'>#{pager}</div>
    </div>
    HTML
    return html
  end

  ##
  # Get the list of events by calling Redmine and transforming.
  def self.getEvents(server)
    uri = "#{server.redmineUrl}/projects/#{server.redmineProject}"
    uri += "/wiki/Events.json?key=#{server.apiKey}"
    response = Net::HTTP.get_response(URI.parse(uri))
    if (response.code.to_i == 200)
      text = JSON.parse(response.body)["wiki_page"]["text"]
      return GenboreeRedmine.transform("Events", text)
    else
      puts "Error grabbing Events from Wiki! Code: #{response.code}"
      return []
    end
  end


  private
  ##
  # Private class method for transforming an Array as a list of events into a
  # string of <li> in a <ul>.
  def self.eventsToHtml(events, start, count)
    list = events.clone

    # Drop previous pages
    list.shift(start)

    # Build the html for our response
    html = ""
    count = 0
    list.each{ |event|
      break if (count >= PAGE_LIST_LEN)
      html << "<li class='event'><div class='date'>#{event['date']}</div>" \
        "<div class='description'>#{event['text']}</div></li>"
      count += 1
    }
    html = "No events!" if (html.empty?)

    # All done, add the list wrapper tags
    return "<ul>#{html}</ul>"
  end
end
