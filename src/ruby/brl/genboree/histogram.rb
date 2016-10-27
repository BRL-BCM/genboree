require 'uri'
require 'brl/db/dbrc'
require 'brl/util/util'
require 'brl/genboree/dbUtil'
require 'brl/genboree/rest/wrapperApiCaller'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/genboreeContext'


module BRL; module Genboree
  #Histogram View for a transformed kbDoc
  class Histogram
   
    LARGE_PX_HEIGHT = 800
    SMALL_PX_HEIGHT = 400


    attr_accessor :rackEnv

    def initialize(userId, rackEnv=nil, kbUri=nil)
      @userId = userId
      @rackEnv = rackEnv
      # This has to be removed once the API is implemented for the transformation doc
      kbUri = "http://genboree.org/REST/v1/grp/clinGenGrid/db/clingen" unless(kbUri)
      @kbUri = kbUri
      @cont = getTransformation()
    end

    # Gets the transformed doc
    # @return [Hash] context rules
    # @raise [RuntimeError] if API request fails
    def getTransformation()
      kbObj = URI.parse(@kbUri)
      gbHost = kbObj.host
      context = Array.new()
      # This API call to be replaced by "/REST/v1/grp/{grp}/kb/{kbName}/doc/{docId}?transformation={tfURL}or{tfID}&format=json"
      genbConf = BRL::Genboree::GenboreeConfig.load()
      apiCaller = BRL::Genboree::REST::WrapperApiCaller.new(gbHost, "", @userId)

      # Transformed output json is now read in from a static file
      fileName = "histogram0.json"
      apiCaller.setRsrcPath("#{kbObj.path}/file/#{fileName}/data?")
      apiCaller.initInternalRequest(@rackEnv, genbConf.machineNameAlias) if(@rackEnv)
      apiCaller.get()
      if(apiCaller.succeeded?)
        context = apiCaller.parseRespBody()
      else
        raise "API ERROR: Check #{apiCaller.parseRespBody()}. "
      end
      return context
    end

    # gets the list of all partitions from the transformed data
    # @return [Array] partitions row and column levels
    def getPartitions()
      partitions = Array.new()
      tmp = Array.new()

      #First partition 
      level = @cont['Data']
      level.each{ |item| tmp << item['name'] }
      partitions << tmp

      while(level.first.key?('data'))
        tmp = []
        level = level.first['data']
        level.each{ |item| tmp << item['name'] }
        partitions << tmp
      end
      return partitions
    end

    # creates html for the histogram
    # @param [String] format smallhtml or largehtml to set the max height for the bar
    # @return [String] histString
    def getHistogram(format)
     
      # get the max bar height     
      if(format.downcase() == 'html' or format.downcase == 'largehtml')
        constantHeight = LARGE_PX_HEIGHT
      elsif(format.downcase == 'smallhtml')
        constantHeight = SMALL_PX_HEIGHT
      else
        raise "FORMAT_INPUT ERROR: Entered format #{format} is not a valid format type. Supported formats include: html/largehtml or smallhtml"
      end 

      partitions = getPartitions()

      # Histogram is a 1xn html table.
      # First partition is the table caption
      # Second partition forms the x-axis

      partition1Name = partitions.first.first
      xAxisLabel = partitions.last

      #get the values of the second partition
      barValues = Array.new()
      tmp = Array.new()
      @cont['Data'].first['data'].each {|item|
        tmp = item['cell']['Value']
        val = (tmp.nil? ? 0 : tmp )
        barValues << val
      }

      histString = ""
      histString << "<div class='histogramFull'>"
      histString << "<div class='title'>#{partition1Name}</div>"
      histString << "<div class='container'>"

      #Bar row
      histString << "<div class='row'>"
      histString << "<div></div>"
      barValues.each{ |val|
        if(val == barValues.max) # get the max Score
          histString << "<div class='max' style='height:#{((constantHeight/val.to_f) * val).round}px;'>#{val}</div>"
        else
          if(val < (barValues.max/constantHeight)*5.0 and val != 0) # Pixel is too small to write the values inside the bar.
           histString << "<div class='outer' style='height:#{((constantHeight/barValues.max.to_f) * barValues.max).round}px;'>"
           histString << "#{val}"
           histString << "<div class='inner' style='height:#{((constantHeight/barValues.max.to_f) * val).round}px;'></div></div>"
          else
           histString << "<div class='outer' style='height:#{((constantHeight/barValues.max.to_f) * barValues.max).round}px;'>"
           histString << "<div class='inner' style='height:#{((constantHeight/barValues.max.to_f) * val).round}px;'>#{val}</div></div>"
          end
        end
        histString << "<div></div>"
      }
      histString << "</div>"#row

      #Axis Row
      histString << "<div class='axisRow'>"
      histString << "<div class='space'></div>"
      barValues.each {|val|
        histString << "<div class='xaxis'></div>"
        histString << "<div class='space'></div>"
      }

      #histString << "<div class='space'></div>"
      histString << "</div>"#axis Row


     #labelRow
     histString << "<div class='labelRow'>"
     histString << "<div class='space'></div>"
     xAxisLabel.each {|label|
       histString << "<div class='labelName'>#{label}</div>"
       histString << "<div class='space'></div>"
     }

     #histString << "<div class='space'></div>"
     histString << "</div>"

     #lastRow
     histString << "<div class='lastrow'>"
     histString << "<div class='space'></div>"
     barValues.each {|val|
       histString << "<div class='xaxis'></div>"
       histString << "<div class='space'></div>"
     }

     #histString << "<div class='space'></div>"
     histString << "</div>" #lastRow

     histString << "</div></div>" #container#histogramFull
     return histString
    end
  end
end;end

