
module BRL; module Genboree; module Abstract; module Resources

# Define functions useful to multiple rest resources dealing with redmine projects
module Redmine

  # Query database for redmine url for this group/project pair
  # @param [BRL::Genboree::DBUtil] dbu
  # @param [Integer] groupId a genboree group id
  # @param [String] projectId a redmine project identifier
  # @return [String] the redmine url root associated with this genboree group/project association
  def getRedmineUrlRoot(dbu, groupId, projectId)
    rv = nil
    redminePrjRecs = dbu.selectRedminePrjByGroupIdAndProjectId(groupId, projectId)
    if(redminePrjRecs.respond_to?(:size) and redminePrjRecs.size == 1)
      rv = redminePrjRecs[0]['url']
    else
      raise "Cannot retrieve the location of the Redmine project #{projectId.inspect} associated with group #{groupId.inspect}"
    end
    return rv
  end

  # Compose a complete url to a Redmine server
  def getRedmineUrl(redmineUrlRoot, redminePrjId, redminePrjSubResource)
    path = "/projects/#{redminePrjId}/#{redminePrjSubResource}"
    redmineUrl = "#{redmineUrlRoot}#{path}"
    return redmineUrl
  end

  # Get the path component of a url to a Redmine server
  def getRedminePath(redmineUrlRoot, redminePrjId, redminePrjSubResource)
    redmineUrl = getRedmineUrl(redmineUrlRoot, redminePrjId, redminePrjSubResource)
    uriObj = URI.parse(redmineUrl)
    return uriObj.path
  end
end

end; end; end; end
