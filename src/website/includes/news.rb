##
# Define all of the methods for generating "What's New" divs.
# Primarily this file will perform two actions
#   * Generate the "What's New" block for the splash page
#   * Generate the full page view of news items, with pager
#

# NOTE: Namespacing was not done for this file as we were unsure of the
#       module names you would like us to use for this type of definition.

class News
  # Constants
  BLOCK_LIST_LEN = 5
  PAGE_LIST_LEN = 10

  ##
  # Generate What's New block for the splash page (50% column)
  def self.getNewsBlock(server)
    return <<-HTML
      <div id='whats-new' class='highlight'>
        <div class="title">
          <i class="fa fa-bullhorn"></i><a href="#{server.context}/News">What's New</a>
        </div>
        #{newsItemsToHtml(getNewsItems(server), 0, BLOCK_LIST_LEN)}
        <div class='more-link'><a href='#{server.context}/News'>more</a></div>
      </div>
    HTML
  end

  ##
  # Generate full What's New page content, with pager.
  def self.getNewsPage(server, page = 0)
    start = page * PAGE_LIST_LEN

    # Build the simple pager
    pager = ""
    list = getNewsItems(server)
    if (page > 0)
      pager << "<a href='?page=#{page - 1}'><i class='fa fa-angle-double-left'></i> Previous Page</a> "
    end
    if (list.count > (page + 1) * PAGE_LIST_LEN)
      pager << "<a href='?page=#{page + 1}'>Next Page <i class='fa fa-angle-double-right'></i></a>"
    end

    # Build the HTML
    html = <<-HTML
    <div id='whats-new'>
      <div class="title">
        <i class="fa fa-bullhorn"></i>What's New
      </div>
      #{newsItemsToHtml(list, start, PAGE_LIST_LEN)}
      <div class='pager'>#{pager}</div>
    </div>
    HTML
    return html
  end

  ##
  # Get the list of news items by calling Redmine and transforming.
  def self.getNewsItems(server)
    uri = "#{server.redmineUrl}/projects/#{server.redmineProject}"
    uri += "/wiki/News.json?key=#{server.apiKey}"
    response = Net::HTTP.get_response(URI.parse(uri))
    if (response.code.to_i == 200)
      text = JSON.parse(response.body)["wiki_page"]["text"]
      return GenboreeRedmine.transform("News", text)
    else
      puts "Error grabbing News Items from Wiki! Code: #{response.code}"
      return []
    end
  end


  private
  ##
  # Private class method for transforming an Array as a list of news items into a
  # string of <li> in a <ul>.
  def self.newsItemsToHtml(news, start, count)
    list = news.clone

    # Drop previous pages
    list.shift(start)

    # Build the html for our response
    html = ""
    count = 0
    list.each{ |item|
      break if (count >= PAGE_LIST_LEN)
      html << "<li class='news'><div class='description'>#{item['text']}</div>" \
        "<div class='date'>#{item['date']}</div></li>"
      count += 1
    }
    html = "No news items to report!" if (html.empty?)

    # All done, add the list wrapper tags
    return "<ul>#{html}</ul>"
  end
end
