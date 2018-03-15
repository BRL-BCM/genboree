
class RedmineAppHelper
  # Get the "mount" for this Redmine using the global "Administration => Settings => [General] => Host name and path"
  #   value. This should be a string like "{host}/{mount}".
  # @note If there is no {mount} component, this will return "/"
  # @note This is checking the Settings, if that's different than what's in config/environment.rb you could have issues.
  # @return The Redmine mount, as configured in the Administration Settings UI.
  def self.redmineMountFromSettings()
    retVal = '/'
    hostNameAndPath = Setting.host_name
    if( hostNameAndPath )
      host, path = *hostNameAndPath.split('/', 2)
      if(path and !path.empty?)
        retVal = path.chomp('/') # possible because of max-of-2-fields arg to split
      else
        retVal = '/'
      end
    end
    return retVal
  end
end