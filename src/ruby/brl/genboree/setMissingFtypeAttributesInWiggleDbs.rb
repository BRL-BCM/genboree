#!/usr/bin/env ruby


# Program for deleting annotations for tracks within a particular region of a chromosome.

# Loading Libraries

require 'rubygems'
require 'brl/genboree/rest/helpers'
require 'pp'
require 'rest-open-uri'
require 'json'
require 'sha1'
require 'cgi'
require 'brl/util/util'
require 'brl/util/textFileUtil'
require 'brl/genboree/rest/apiCaller'
require 'rack'
include BRL::Genboree::REST

SEC_FILE = "/usr/local/brl/home/manuelg/.secFile"

PIXELHIGHTVALUE = "53.0"

  class GenboreePassword 
    attr_accessor :secFile, :user, :passwd

    def initialize(secFile = SEC_FILE)
      @secFile = secFile
      loadSecretFile()
    end

   def parseFile()
         reader = File.open(@secFile, "r")

       reader.each { |line|
        next if(line =~ /^\s*#/) # skip comment lines
        next if(line =~ /^\s*$/) # skip blank lines
        if(line =~ /^\s*(\S+)\s*=\s*(.+)$/)
          @user = $1.strip
          @passwd = $2.strip
        end     
      }
       reader.close()
    end

    def loadSecretFile()
      raise "ERROR: The genboree passwd file is missing or unreadable! Cannot load sec file." if(@secFile.nil? or @secFile.empty? or !File.exist?(@secFile) or !File.readable?(@secFile))
      parseFile()   
    end

  end



class AddTrackAttribute

  attr_accessor :host, :group, :database, :tAttName, :tAttValue, :usr, :pwd
  attr_accessor :trackNames, :attrToCopy, :colorFlag, :styleFlag, :attColor
  attr_accessor :attRank, :attDispFlag, :attAddToDisplay, :attRemoveFromDisplay

  def initialize(host, group, database, tracks=nil, tAttName=nil,
                 tAttValue=nil, attrToCopy=nil, atColor=nil,
                 atRank = nil, atDispFlag = nil )
    @host = host.to_s
    @group = Rack::Utils.escape(group)
    @database = Rack::Utils.escape(database)
    @colorFlag = false
    @styleFlag = false
    @attRemoveFromDisplay = false
    @attAddToDisplay = false
    
    if(atColor.nil?)
      @attColor = "#FF0000"
    else
      @attColor = atColor
    end
    
    if(atRank.nil?)
      @attRank = 1
    else
      @attRank = atRank
    end
    
    if(atDispFlag.nil?)
      @attDispFlag = 1
    else
      @attDispFlag = atDispFlag
    end
    

    genbUserPassWd = GenboreePassword.new()
    @usr = genbUserPassWd.user
    @pwd = genbUserPassWd.passwd

    if(!tracks.nil?)
      @trackNames = tracks.strip.split(/,/)
    else
      @trackNames = extractHDHVTrackNamesFromDatabase()
    end

    if(!tAttName.nil?)
       @tAttName =  tAttName.strip.split(/,/)
    else
      @tAttName =  ['gbTrackUserMax', 'gbTrackUserMin', 'gbTrackPxHeight']
    end
    
    if(tAttName =~ /color/i)
      @colorFlag = true
      @tAttName = "color"
    elsif(tAttName =~ /style/i)
      @styleFlag = true
      @tAttName = "style"
    elsif(tAttName =~ /display/i)
      @attAddToDisplay = true
    elsif(tAttName =~ /rematt/i)
      @attRemoveFromDisplay = true          
    end


    if(!tAttValue.nil?)
       @tAttValue =  tAttValue.strip.split(/,/)
    else
      @tAttValue =  nil
    end

    if(!attrToCopy.nil?)
       @attrToCopy =  attrToCopy.strip.split(/,/)
    else
      @attrToCopy =  nil
    end

    if(@tAttValue.nil? and @attrToCopy.nil?)
        @attrToCopy =  ['gbTrackDataMax', 'gbTrackDataMin']
    end

    if(@tAttValue.nil?)
      if(!@attrToCopy.nil? and !@tAttName.nil? and @attrToCopy.length != @tAttName.length)
        setTrackAttributesFromExistingAttValues(true)
      else
        setTrackAttributesFromExistingAttValues(false)
      end
    else
      if(@colorFlag)
        setTrackColor()
      elsif(@styleFlag)
        setTrackStyle()
      elsif(@attAddToDisplay)
          displayAttributes()
      elsif(@attRemoveFromDisplay)
          removeAttributes()
      else
        setTrackAttributeValues()
      end
    end
    clearCache()
  end

  def setTrackAttributesFromExistingAttValues(useDefaults)
    @trackNames.each{|trk|
       counter = 0
      @attrToCopy.each{ |attCopy|
        attValue = getAttributeValue(trk, attCopy)
        attName = @tAttName[counter]
        setTrackAttribute(trk, attName, attValue)
        counter += 1
      }
      if(useDefaults)
        attName = @tAttName[counter]
        setTrackAttribute(trk, attName, PIXELHIGHTVALUE)
      end
    }
  end

  def setTrackAttributeValues()
    @trackNames.each{|trk|
       counter = 0
      @tAttName.each{ |attName|
        attValue = @tAttValue[counter]
        setTrackAttribute(trk, attName, attValue)
        counter += 1
      }
    }
  end

  def extractHDHVTrackNamesFromDatabase()
    trackNames = Array.new()
    apiCaller = ApiCaller.new("#{@host}", "/REST/v1/grp/#{@group}/db/#{@database}/trks", "#{@usr}", "#{@pwd}")
    apiCaller.get()
    allTracks = apiCaller.parseRespBody()
    allTracks['data'].each{|trk|
      path= "/REST/v1/grp/#{@group}/db/#{@database}/trk/#{Rack::Utils.escape(trk['text'])}/attribute/gbTrackDataSpan/value"
      apiCaller.setRsrcPath(path)
      apiCaller.get()
      rsp = apiCaller.parseRespBody
      if(rsp['status']['statusCode'] == 'OK')
        trackNames << trk['text']
      end
    }
    return trackNames
  end

  def getAttributeValue(trackName, attributeName)
    apiCaller = ApiCaller.new("#{@host}", "/REST/v1/grp/#{@group}/db/#{@database}/trks", "#{@usr}", "#{@pwd}")
    path = "/REST/v1/grp/#{@group}/db/#{@database}/trk/#{Rack::Utils.escape(trackName)}/attribute/#{attributeName}/value"
    apiCaller.setRsrcPath(path)
    apiCaller.get()
    rsp = apiCaller.parseRespBody
    attributeValue = rsp['data']['text']
    if(rsp['status']['statusCode'] == 'OK')
      return attributeValue
    else
      return nil
    end
  end

  def setTrackAttribute(trackName, attributeName, attributeValue)
    apiCaller = ApiCaller.new("#{@host}", "/REST/v1/grp/#{@group}/db/#{@database}/trks", "#{@usr}", "#{@pwd}")
    path = "/REST/v1/grp/#{@group}/db/#{@database}/trk/#{Rack::Utils.escape(trackName)}/attribute/#{attributeName}/value"
    apiCaller.setRsrcPath(path)
    payload = {"data"=>{"text"=>"#{attributeValue}"}}
    apiCaller.put(payload.to_json)
  end

  def displayAttributes()
    @trackNames.each{|trk|
       counter = 0
      @tAttValue.each{ |name|
        displayExistingAttribute(trk, name, @attDispFlag, @attRank, @attColor)
        counter += 1
      }
    }
  end
  
  
  def removeAttributes()
    @trackNames.each{|trk|
       counter = 0
      @tAttValue.each{ |name|
        removeExistingAttributeFromDisplay(trk, name)
        counter += 1
      }
    }
  end
 
  def displayExistingAttribute(trackName, attributeName, flag, rank, color)
    apiCaller = ApiCaller.new("#{@host}", "/REST/v1/grp/#{@group}/db/#{@database}/trks", "#{@usr}", "#{@pwd}")
    path = "/REST/v1/grp/#{@group}/db/#{@database}/trk/#{Rack::Utils.escape(trackName)}/attribute/#{Rack::Utils.escape(attributeName)}/display"
    apiCaller.setRsrcPath(path)
    payload = {"data"=>{"flags"=>"#{flag}", "color"=>"#{color}", "rank"=>"#{rank}"}}
    apiCaller.put(payload.to_json)
    rr = apiCaller.parseRespBody  
    if(!(rr['status']['msg']).nil? and rr['status']['msg'] != '' )
      puts rr['status']['msg']
    end
  end
  
   def removeExistingAttributeFromDisplay(trackName, attributeName)
    apiCaller = ApiCaller.new("#{@host}", "/REST/v1/grp/#{@group}/db/#{@database}/trks", "#{@usr}", "#{@pwd}")
    path = "/REST/v1/grp/#{@group}/db/#{@database}/trk/#{Rack::Utils.escape(trackName)}/attribute/#{Rack::Utils.escape(attributeName)}/display"
    apiCaller.setRsrcPath(path)
    apiCaller.delete
    rr = apiCaller.parseRespBody  
    if(!(rr['status']['msg']).nil? and rr['status']['msg'] != '' )
      puts rr['status']['msg']
    end
  end 
  

  def clearCache()
    path = "/REST/v1/grp/#{@group}/db/#{@database}/browserCache"
    apiCaller = ApiCaller.new("#{@host}", path, "#{@usr}", "#{@pwd}")
    apiCaller.delete()
  end
  
  def setTrackColor()
    @trackNames.each{|trk|
       counter = 0
      @tAttValue.each{ |color|
        changeColor(trk, color)
        counter += 1
      }
    }
  end

  def changeColor(trackName, color)
    apiCaller = ApiCaller.new("#{@host}", "/REST/v1/grp/#{@group}/db/#{@database}/trks", "#{@usr}", "#{@pwd}")
    path = "/REST/v1/grp/#{@group}/db/#{@database}/trk/#{Rack::Utils.escape(trackName)}/color"
    apiCaller.setRsrcPath(path)
    payload = {"data"=>{"text"=>"#{color}"}}
    apiCaller.put(payload.to_json)
    rr = apiCaller.parseRespBody
    
    if(!(rr['status']['msg']).nil? and rr['status']['msg'] != '' )
      puts rr['status']['msg']
    end
    path = "/REST/v1/grp/#{@group}/db/#{@database}/trk/#{Rack::Utils.escape(trackName)}/defaultColor"
    apiCaller.setRsrcPath(path)
    payload = {"data"=>{"text"=>"#{color}"}}
    apiCaller.put(payload.to_json)
  end
 
  def setTrackStyle()
    @trackNames.each{|trk|
       counter = 0
      @tAttValue.each{ |style|
        changeStyle(trk, style)
        counter += 1
      }
    }
  end
 

  
  def changeStyle(trackName, style)
    if(style =~ /global/i)
      style = "Global Score Barchart (big)"
    elsif(style =~ /local/i)
      style = "Local Score Barchart (big)"
    end
    apiCaller = ApiCaller.new("#{@host}", "/REST/v1/grp/#{@group}/db/#{@database}/trks", "#{@usr}", "#{@pwd}")
    path = "/REST/v1/grp/#{@group}/db/#{@database}/trk/#{Rack::Utils.escape(trackName)}/style"
    apiCaller.setRsrcPath(path)
    payload = {"data"=>{"text"=>"#{style}"}}
    apiCaller.put(payload.to_json)
    rr = apiCaller.parseRespBody  
    if(!(rr['status']['msg']).nil? and rr['status']['msg'] != '' )
      puts rr['status']['msg']
    end
    path = "/REST/v1/grp/#{@group}/db/#{@database}/trk/#{Rack::Utils.escape(trackName)}/defaultStyle"
    apiCaller.setRsrcPath(path)
    payload = {"data"=>{"text"=>"#{style}"}}
    apiCaller.put(payload.to_json)
    rr = apiCaller.parseRespBody  
    if(!(rr['status']['msg']).nil? and rr['status']['msg'] != '' )
      puts rr['status']['msg']
    end
  end 
  ## "text"=>"Global Score Barchart (big)"
  ## "Local Score Barchart (big)"
end

class RunScript
  VERSION_NUMBER="1.0"
  DEFAULTUSAGEINFO="

    Usage: #Program to populate attribute values tracks, if no attribute names are provided the default track attributes
    will be populated 'gbTrackUserMax', 'gbTrackUserMin', 'gbTrackPxHeight' using the values from 'gbTrackDataMax', 'gbTrackDataMin' and 53.

    Arguments:
    -o  --host  #url of host (required)
    -g  --group # genboree group (required)
    -d  --database  #name of the database (required)
    -t  --trackName # track name updated you can pass multiple tracks as a comma separated list (optional) (if inputting through command line)
    -n  --tAttName # track attribute name you can pass multiple attribute names as a comma separated list (optional) (if inputting through command line)
    -p  --tAttValue #track attribute to use as template you can pass multiple attribute names as a comma separated list (optional) (if inputting through command line)
    -c  --tAttrToCopy # track attribute to use as template you can pass multiple attribute names as a comma separated list  (optional) (if inputting through command line)
    -a  --attColor  # the color to display the attribute name below the name of the track
    -b  --attRank  # the order to display the attribute name 
    -f  --attDispFlag # 0 to display only the name of the attribute
    -v  --version #Version of the program
    -h  --help #Display help

  "
    def self.printUsage(additionalInfo=nil)
      puts DEFAULTUSAGEINFO
      puts additionalInfo unless(additionalInfo.nil?)
      if(additionalInfo.nil?)
        exit(0)
      else
        exit(15)
      end
    end

    def self.printVersion()
      puts VERSION_NUMBER
      exit(0)
    end

    def self.parseArgs()
      methodName="addTrackAttribute"
      optsArray=[
        ['--host','-o',GetoptLong::REQUIRED_ARGUMENT],
        ['--group','-g',GetoptLong::REQUIRED_ARGUMENT],
        ['--database','-d',GetoptLong::REQUIRED_ARGUMENT],
        ['--trackName','-t',GetoptLong::OPTIONAL_ARGUMENT],
        ['--tAttName','-n',GetoptLong::OPTIONAL_ARGUMENT],
        ['--tAttValue','-p',GetoptLong::OPTIONAL_ARGUMENT],
        ['--tAttrToCopy','-c',GetoptLong::OPTIONAL_ARGUMENT],
        ['--attColor', '-a', GetoptLong::OPTIONAL_ARGUMENT],
        ['--attRank', '-b', GetoptLong::OPTIONAL_ARGUMENT],
        ['--attDispFlag', '-f', GetoptLong::OPTIONAL_ARGUMENT],
        ['--version','-v',GetoptLong::NO_ARGUMENT],
        ['--help','-h',GetoptLong::NO_ARGUMENT]
      ]
      progOpts=GetoptLong.new(*optsArray)
      optsHash=progOpts.to_hash
      if(optsHash.key?('--help'))
        printUsage()
      elsif(optsHash.key?('--version'))
        printVersion()
      end
      printUsage("USAGE ERROR: some required arguments are missing") unless(progOpts.getMissingOptions().empty?)
      return optsHash
    end

    def self.addTrackAttribute(optsHash)
        AddTrackAttribute.new(optsHash['--host'], optsHash['--group'],
                              optsHash['--database'], optsHash['--trackName'],
                              optsHash['--tAttName'], optsHash['--tAttValue'],
                              optsHash['--tAttrToCopy'], optsHash['--attColor'],
                              optsHash['--attRank'], optsHash['--attDispFlag'])
    end
end

optsHash = RunScript.parseArgs()
RunScript.addTrackAttribute(optsHash)
