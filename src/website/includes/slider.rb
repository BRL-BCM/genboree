class Slider
  ###
  # This method will return an array of paths / caption data for all of the
  # images to be included in the Image Slider based on the Redmine Wiki lists.
  def self.getImageInfo(server)
    uri = "#{server.redmineUrl}/projects/#{server.redmineProject}"
    uri += "/wiki/Image.json?key=#{server.apiKey}"
    response = Net::HTTP.get_response(URI.parse(uri))
    if (response.code.to_i == 200)
      text = JSON.parse(response.body)["wiki_page"]["text"]
      return GenboreeRedmine.transform("Image", text)
    else
      puts "Error grabbing Image from Wiki! Code: #{response.code}"
      return []
    end
  end
end
