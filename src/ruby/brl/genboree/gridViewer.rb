#!/usr/local/env ruby

require 'uri'
require 'brl/util/util'
require 'brl/genboree/rest/wrapperApiCaller'
require 'brl/genboree/kb/transformers/transformedDocHelper'
include BRL::Genboree::KB::Transformers

module BRL; module Genboree

# Display transformed kbDoc as a html table(grid)
class GridViewer
  
  TRANSFORMED_DOC_KEYS = { :nameKey => "name", :dataRootKey => "Data",
                           :specialValueKey => "Special Value Rules", :contextKey => "Contexts",
                           :dataChildrenKey => "data", :leafKey => "cell"
                         }
  SUPP_FORMATS = {:HTML =>  nil, :SMALLHTML => nil}
  attr_accessor :rules

  def initialize(transformedDoc)
    @transformedDoc = transformedDoc
    @rules = @transformedDoc[TRANSFORMED_DOC_KEYS[:specialValueKey]] rescue nil
  end

  # Makes the Context string to display
  # @param [String] format small or largehml table display
  # @return [String] popstring
  def getContextString(format)
    popstring = ""
    contextString = ""
    if (SUPP_FORMATS.key?(format))
      info = @transformedDoc[TRANSFORMED_DOC_KEYS[:contextKey]]
      sorted = info.sort_by { |k, v| v["Rank"] }

      # Get the specific css classes with respect to the rank value.
      #smallhtml format show contexts with ranks 1 and 2 only
      sorted.each_with_index{ |val, index|
        con = nil
        className =  "gb-context-rank#{val[1]["Rank"]}"
        className = "gb-context-rankX" if(val[1]["Rank"] > 3)
        contextString = "#{val[0]}: #{val[1]["value"].join("\t")}"
        #$stderr.puts contextString
        #$stderr.puts "Length: #{contextString.length}"
        # make tool tip if the context string is longer.
        if(format  == :SMALLHTML and val[1]["Rank"] <= 2 )
          if(contextString.length > 20)
            con = "#{contextString[0..15]}. . ."
          end
          if(con)
            popstring << "<span class='#{className}' title='#{contextString}'>#{con}</span> <br>"
          else
            popstring << "<span class='#{className}'>#{val[0]}: #{val[1]["value"].join("\t")}</span> <br>"
          end
        elsif(format == :HTML)
          if(contextString.length > 35)
            con = "#{contextString[0..18]}. . ."
          end
          if(con)
            popstring << "<span class='#{className}' title='#{contextString}'>#{con}</span><br>"
          else
            popstring << "<span class='#{className}'>#{val[0]}: #{val[1]["value"].join("\t")}</span><br>"
          end
        end
      }
    else
      raise ArgumentError, "Format Error: Format #{format.inspect} is not supported. Supported formats are #{SUPP_FORMATS.keys.inspect}."
    end
    return popstring
  end

  # Gets the special values and respective types to display
  # @return [String] specialStr
  def applyRules()
    specialStr = ""
    # if rules exist apply it
    if(!@rules.empty? and !@specialValues.empty?)
      specialStr = "Special Values found for the types: <br><ul class='list'>"
      @specialValues.each_key {|type|
        specialStr << "<li class='list'><b>#{type.upcase()}</b></li><ul>"
        specialStr << "<li>#{@specialValues[type].keys().join("</li><li>")}</li>"
      }
      specialStr << "</ul></ul>"
    end
    return specialStr
  end
  

  def filtertransformedDoc()
    @specialValues = {}
    dataTree = Marshal.load(Marshal.dump(@transformedDoc))
    namekeys = TransformedDocHelper.getNameKeys(@transformedDoc, {:getKey => {'name' => nil}}, false)
    allPartitions = namekeys['name']  
    keys = allPartitions.first()
      allPartitions[1..allPartitions.length-2].each{|partition|
        keys = getKeys(keys, partition)
      }
    unless(@rules.empty?)
      keys.each{|key|
        filterKeys = []
        allPartitions.last.each{|part|
          fullKey = "#{key}.#{part}"
          filterKeys << fullKey if(@rules.key?(fullKey) and @rules[fullKey]['value'] == 'invalid')
        }
        #$stderr.puts "FILTERKEYS: #{filterKeys.inspect}"
        if(filterKeys.size() == allPartitions.last.size())
          #$stderr.puts "FILTERKEYSTO BE REMOVED: #{filterKeys.inspect}"
          filterKeys.each{|filterKey|
            count = TransformedDocHelper.getValFromPath(dataTree, filterKey, {:getValueKey => "cell"})
            if(count)
              @specialValues[@rules[filterKey]['value']] = {} unless(@specialValues.key?(@rules[filterKey]['value']))
              @specialValues[@rules[filterKey]['value']][filterKey] = ""
            end
          } 
          retVal = TransformedDocHelper.deleteNodeFromTree(dataTree, key)
            raise "Error: Failed to remove the node #{key} from the transformedDoc" if(retVal != :deleted)
     end
      }
    end
    return dataTree
  end

  # Creates the html for a transformed kbDoc
  # @param [String] format html or small html to display
  # @param [boolean] onclick appends onclick function to the respective elements
  # @return [String] fullTable html table 
  def getTable(viewFormat, onclick=false, showHisto=false)
    
    # ALL the cells in a column that are marked as invalid in the 
    # transformation document are removed. This is not displayed on 
    # the table
    dataTree = filtertransformedDoc()
    #$stderr.puts dataTree.inspect
    newPartitions = []
    metadata = []

    # get metadata and partition names
    newKeys = TransformedDocHelper.getNameKeys(dataTree, {:getKey => {'name' => nil,'metadata' => nil}}, false)

    newKeysFirst = TransformedDocHelper.getNameKeys(dataTree, {:getKey => {'name' => nil,'metadata' => nil}}, true)
    newPartitions  =  newKeys['name']
    metadata = newKeys['metadata']
    if(newPartitions.size > 2)
      newPartitions[1] =  newKeysFirst['name'][1] + newKeys['name'][1]
      newPartitions[1] = newPartitions[1].uniq
      metadata[1] =  newKeysFirst['metadata'][1] + newKeys['metadata'][1]
      metadata[1] = metadata[1].uniq
    end
    firstLevel = newPartitions.first()
    lastLevel = newPartitions.last()

    tableHash = {}
    # get the table hash from the filtered dataTree
    # this is used for the html table generation
    firstLevel.each{ |level| tableHash[level] = [] }
    if(newPartitions.size == 2)
      firstLevel.each{ |part|
        tableHash[part] << dataTree[TRANSFORMED_DOC_KEYS[:dataRootKey]][firstLevel.index(part)] #cont['Data'][2]['data']
      }
    elsif(newPartitions.size > 2)
      middlePart = []
      firstLevel.each{ |part|
        dataTree["Data"][firstLevel.index(part)]["data"].each{|stren| 
          tableHash[part] << stren
          middlePart << stren["name"]
        }
      }
    end
    #Format Settings
    if(viewFormat == :SMALLHTML)
      mainClass = "gb-grid-small"
    elsif(viewFormat == :HTML)
      mainClass = "gb-grid-large"
    else
      $stderr.puts "Format not SUPPORTED: Set to default format: :HTML"
      mainClass = "gb-grid-large"
    end
    # Make the table
    fullTable = ""
    fullTable = "<div class='gb-transformedtable' align='center'>"
    fullTable << "<table class='#{mainClass}'>"
    fullTable << "<tr>"
   
    # Define the first cell with context info
    fullTable << "<th class='gb-context' rowspan='#{newPartitions.size() - 1}'>#{getContextString(viewFormat)}</th>"

    # Partition 1 headers
    classname = "gb-part1-header"
    firstLevel.each_with_index{ |header, ind|
      valueBasedCls = "#{classname}-#{header.downcase()}".makeSafeStr(:ultra)
      indexBasedCls = "#{classname}-#{ind+1}"
      elmId = header.gsub(/\s+/, '')
      if(onclick)
        fullTable << "<th id='#{elmId}' class='#{classname} #{indexBasedCls} #{valueBasedCls}' onclick=\"clickPartition('#{elmId}', '#{header}', '#{header}', #{jsonToJsObj(metadata.first[ind].to_json)})\" colspan='#{tableHash[header].size()}'>#{header.to_s}"
      else
        fullTable << "<th id='#{elmId}' class='#{classname} #{indexBasedCls} #{valueBasedCls}' colspan='#{tableHash[header].size()}'>#{header.to_s}"
      end
      if(!metadata.first.empty? and !metadata.first[ind].nil?)
        fullTable << "<div class='toggleText' style='display: none'>"
        metadata.first[ind].each_key{|metKey|
          fullTable << "#{metKey}: #{metadata.first[ind][metKey].join(',')} "
        }
        fullTable << "</div>"
      end
      fullTable << "</th>"
    }
    fullTable << "</tr>"

    # Partition 2 headers 
    totalcols = 0
    classname = "gb-part2-header"
    if(newPartitions.size > 2)
     fullTable << "<tr>"
     firstLevel.each{ |path|
       tableHash[path].each{ |item|
         totalcols = totalcols + 1
         elmLabel = item['name']
         meta = item['metadata'] rescue nil
         parPath = "#{path}.#{elmLabel}"
         elmId = parPath.gsub(/\s+/, '')
         valueBasedCls = "#{classname}-#{elmLabel.downcase()}".makeSafeStr(:ultra)
         indexBasedCls = "#{classname}-#{totalcols}"
         if(onclick)
           fullTable << "<th id='#{elmId}' class='#{classname} #{indexBasedCls} #{valueBasedCls}' onclick=\"clickPartition('#{elmId}', '#{parPath}', '#{elmLabel}', #{jsonToJsObj(meta.to_json)})\">#{item["name"].to_s}</th>"
         else
           fullTable << "<th id='#{elmId}' class='#{classname} #{indexBasedCls} #{valueBasedCls}' > #{item["name"].to_s}</th>"
        end
       }
     }
     fullTable << "</tr>"
   end
   # get all the cell values at one place
    table = Array.new()
    tablekeys = Array.new()
    firstLevel.each{ |key|
      tableHash[key].each {|item|
        table << item
        tablekeys << key
     }
   }

   # Partition 3 headers and data cell values
   classname = "gb-part3-header"
   classdataCell = "gb-dataCell"
   lastLevel.each_with_index{|val, ind|
     fullTable << "<tr>"
     valueBasedCls = "#{classname}-#{val.downcase}".makeSafeStr(:ultra)
     elmId = val.gsub(/\s+/, '') 
     if(onclick)
       #fullTable << "<th id='#{elmId}' class='#{classname} #{valueBasedCls}' onclick=\"clickPartition('#{elmId}', '#{val}', '#{val}', #{jsonToJsObj(metadata.last[ind].to_json)})\">#{val}"     
       fullTable << "<th id='#{elmId}' class='#{classname} #{valueBasedCls}' data-qtip=\"Add/Remove tags\" onclick=\"clickPartition('#{elmId}', '#{val}', '#{val}', #{jsonToJsObj(metadata.last[ind].to_json)})\"> <i class=\"fa fa-list\"></i> #{val}"     
     else
       fullTable << "<th id='#{elmId}' class='#{classname} #{valueBasedCls}'>#{val}"
     end
     fullTable << "<a class='showHisto'  href=\"#\" onclick=\"showHisto(\'#{val}\', \'#{ind}\')\"></a>" if(showHisto)
     if(!metadata.last.empty? and !metadata.last[ind].nil?)
       fullTable << "<div class=\'toggleText\' style=\'display: none\'>"
       metadata.last[ind].each_key{|metKey|
         fullTable << "#{metKey}: #{metadata.last[ind][metKey].join(',')} "
       }
       fullTable << "</div>"
     end
     fullTable << "</th>"


     table.each_with_index{ |tab, index|
       cellString = ""
       count = tab["data"][ind]["cell"]["value"]
       meta = tab['data'][ind]['cell']['metadata'] rescue nil
       name1 = nil
       name2 = tab["name"]
       if(@rules.empty? and newPartitions.size() <= 2)
         parPath = "#{name2}.#{val}"
         elmId = val.gsub(/\s+/, '')
         if(onclick)
           cellString = "<td id='#{elmId}' class='#{classdataCell} #{classdataCell}-plain' onclick=\"clickCell('#{elmId}', '#{parPath}', '#{val}', #{jsonToJsObj(meta.to_json)})\">#{count}</td>"
         else
           cellString = "<td id='#{elmId}' class='#{classdataCell} #{classdataCell}-plain'>#{count}</td>"
         end
       else
        name1 = tablekeys[index]
        parPath = "#{name1}.#{name2}.#{val}"
        elmId = parPath.gsub(/\s+/, '')
        specialCls = "#{classdataCell}-#{name1.downcase()}".makeSafeStr(:ultra)
        indexBasedCls = "#{classdataCell}-gb-part1-header-#{firstLevel.index(name1)}"
        rule = @rules[parPath] rescue nil
        if(!count.nil? and !@rules[parPath].nil?)
            @specialValues[@rules[parPath]['value']] = {} unless(@specialValues.key?(@rules[parPath]['value']))
            @specialValues[@rules[parPath]['value']][parPath] = ""
            if(onclick)
              cellString = "<td id='#{elmId}' class='#{classdataCell} #{classdataCell}-invalidCount' onclick=\"clickCell('#{elmId}', '#{parPath}', '#{val}', #{jsonToJsObj(meta.to_json)})\" class=\'invalidCount\'>#{count}</td>"
            else
              cellString = "<td id='#{elmId}' class='#{classdataCell} #{classdataCell}-invalidCount'>#{count}</td>"
            end
        elsif(count)
          #$stderr.puts "COUNT: #{count} ELMID: #{elmId}"
          if(onclick)
            cellString = "<td id='#{elmId}' class='#{classdataCell} #{indexBasedCls} #{specialCls}' onclick=\"clickCell('#{elmId}', '#{parPath}', '#{val}', #{jsonToJsObj(meta.to_json)})\">#{count}</td>"
          else
            cellString = "<td id='#{elmId}' class='#{classdataCell} #{indexBasedCls} #{specialCls}'>#{count}</td>"
          end
        end
      end
      if(count.nil?)
        if(!@rules.empty? and !@rules[parPath].nil?)
          valueBasedCls = "#{classdataCell}-invalid"
        else
          valueBasedCls = "#{classdataCell}-plain"
        end
        if(onclick)
          cellString = "<td id='#{elmId}' class='#{classdataCell} #{valueBasedCls}' onclick=\"clickCell('#{elmId}', '#{parPath}', '#{val}', #{jsonToJsObj(meta.to_json)})\" ></td>"
        else
          cellString = "<td id='#{elmId}' class='#{classdataCell} #{valueBasedCls}'></td>"
        end
      end
      fullTable << cellString
    }
    fullTable << "</tr>"
  }
  specialString = applyRules()
   if(!@specialValues.keys().empty? and (viewFormat  == :HTML))
      fullTable << "<tr class='gb-special'><td class='gb-specialStr' colspan='#{totalcols+1}' ><b>Note: </b>#{applyRules()}</td></tr>"
   end
   fullTable << "</table></div>"
   return fullTable
  end

  ##########################
  # HELPER METHODS
  #########################
  
  # Makes new partition paths from a new set of partition names
  # separated by a delim
  # @param [Array<String>] tmp list of partition names
  # @param [Array<String>] part list of new partition names that will be appended to the elements of @tmp@ 
  # @param [String] sep delim joining paritition names
  # @return [Array<String>] retVal list of new names separated by @sep@
  def getKeys(tmp, part, sep=".")
   retVal = []
   tmp.each{|tm|
     s = tm.dup
     part.each{|ii|
       newKey = s + sep + ii
       retVal << newKey
        }
      }
      return retVal
    end

 # Transform JSON string to JS object string; improves html source code readability
 # and reduces client-side JSON parsing
 # @param [String] json
 # @return [String] an associated JS object for source code    
  def jsonToJsObj(json)
    jsStr = ""
    pattern = /\"([^\"]+)\":/
    json.each_line { |line|
      matchData = pattern.match(line)
      if(matchData)
        jsStr << line.gsub(matchData[0], matchData[1] + ":")
      else
        jsStr << line
      end
    }
    jsStr = jsStr.gsub(/\"/, '\'')
    return jsStr
  end

end
end; end;
