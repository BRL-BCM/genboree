
require 'json'
require 'brl/util/util'
require 'brl/util/textFileUtil'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/abstract/resources/project'
require 'brl/genboree/abstract/resources/abstractProjectComponent'

module BRL ; module Genboree ; module Abstract ; module Resources
  # Class representing the list of news items related to a particular project
  class ProjectNews < AbstractProjectComponent
    # The name of the file that has the data contents or the index of contents
    DATA_FILE = 'genb^^optional/updates.json'
    # The type of data stored in the data file
    DATA_FORMAT = :JSON

    # Represent as an ExtJS TreeNode config object. When converted to JSON (via #to_json)
    # this will result in a JSON string that is compliant with ExtJS's TreeNode config object.
    # We don't convert it to JSON here because you may be building a larger tree of which this is only
    # a sub-branch.
    #
    # Here it results in a "News" folder that has each news item as a file leaf node that is the news item date.
    #
    # [+expanded+]  [optional; default=false] true if the node should start off expanded, false otherwise
    # [+returns+] A Hash representing the component, often having an Array for the :children key (which is an Array of Hashes defining child nodes...)
    def to_extjsTreeNode(expanded=false)
      if(!self.empty?)
        # Create the news node
        retVal = { :text => "News", :leaf => false, :cls => "folder", :expanded => expanded, :allowDrag => false, :allowDrop => false }
        # Add children
        retVal[:children] = []
        @data.each { |newsHash|
          next if(newsHash.nil? or newsHash.has_value?(nil))
          retVal[:children] << { :text => CGI.escapeHTML(newsHash['date']), :leaf => true, :cls => "file", :allowDrag => false, :allowDrop => false }
        }
      else
        retVal = {}
      end
      return retVal
    end

    # Validate news item list JSON string
    # [+newsJsonStr+] The news json string to validate
    # [+returns+]     true if news json is ok; else false
    def self.validateNewsJson(newsJsonStr)
      retVal = false
      unless(newsJsonStr.nil?)
        if(newsJsonStr.empty?) # empty list automatically ok
          retVal = true
        else
          # try to parse as json
          begin
            newsItems = JSON.parse(newsJsonStr)
            # should be an array of news items
            if(newsItems.is_a?(Array))
              # each date field should be a string in the form YYYY/MM/DD
              allDatesOk = true
              newsItems.each { |newsItem|
                if(newsItem.is_a?(Hash) and newsItem.key?('date'))
                  timeHash = Date._parse(newsItem['date'])
                  unless(timeHash.key?(:year) and timeHash.key?(:mday) and timeHash.key?(:mon))
                    allDatesOk = false
                    break
                  end
                else
                  allDatesOk = false
                  break
                end
              }
              retVal = allDatesOk
            else
              retVal = false
            end
          rescue => err
            retVal = false
          end
        end
      end
      return retVal
    end
  end
end ; end ; end ; end
