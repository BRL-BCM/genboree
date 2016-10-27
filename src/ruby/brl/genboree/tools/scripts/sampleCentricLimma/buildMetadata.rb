#!/usr/bin/env ruby
require 'json'
require 'fileutils'
require 'cgi'
require 'brl/util/util'
require 'brl/util/emailer'
require 'brl/genboree/rest/wrapperApiCaller'
require 'brl/genboree/helpers/expander'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'

include BRL::Genboree::REST

# TODO yet another idiosyncratic
class BuildMetadata
  METADATA_TOOL_ERROR_EXIT_STATUS = 121

  def initialize(optsHash)
    @trackSet   = File.expand_path(optsHash['--trackFile'])
    @attributes = optsHash['--attributes']

    @sampleID   = optsHash['--sampleID']
    @apiDBRCkey = optsHash['--apiDBRC']
    @db         = optsHash['--db']
    @userId = optsHash['--userId']
    @scratch    = File.expand_path(optsHash['--scratch'])

    @gbConfFile     = "/cluster.shared/local/conf/genboree/genboree.config.properties"
    @grph           = BRL::Genboree::REST::Helpers::GroupApiUriHelper.new(@gbConfFile)
    @dbhelper       = BRL::Genboree::REST::Helpers::DatabaseApiUriHelper.new(@gbConfFile)
    @trackhelper    = BRL::Genboree::REST::Helpers::TrackApiUriHelper.new(@gbConfFile)

    dbrc 	    = BRL::DB::DBRC.new(nil, @apiDBRCkey)
    @pass 	    = dbrc.password
    @user 	    = dbrc.user

    @metadataHash   = Hash.new {|k,v| k[v] = Hash.new{|a,b| a[b]= "" }}
    @attributesArry = @attributes.split(",")

    # CC we need to capture erroneous metadata builds
    @toolExitStatus = 0
  end

  ##build hash of sampleID and track name to get mapping
  def mapTracks
    $stderr.debugPuts(__FILE__, __method__, "INFO" , "BuildMetaData: Starting map tracks ")
    if (@toolExitStatus!=0) then
      $stderr.debugPuts(__FILE__, __method__, "INFO" , "BuildMetaData: skip Starting map tracks ")
      return
    end
    @trackMap = {}
    file = File.open("#{@scratch}/tmpFile.txt")
    @numberOfTracks = 0
    file.each{|track|
      @numberOfTracks += 1
      track.strip!
      trackName = @trackhelper.extractName(track)
      uri  = URI.parse(track)
      #uri  = URI.parse(track)
      db   = @dbhelper.extractName(track)
      grp  = @grph.extractName(track)
      trk  = @trackhelper.extractName(track)
      host = uri.host
      rcscPath = "/REST/v1/grp/{grp}/db/{db}/trks/attributes/map?attributeList={attrList}&minNumAttributes={minNum}"
      rcscPath << "&gbKey=#{@dbhelper.extractGbKey(track)}" if(@dbhelper.extractGbKey(track))
      apiCaller = WrapperApiCaller.new(host,rcscPath,@userId)
      hr = apiCaller.get(
        {
          :grp => grp,
          :db => db,
          :attrList => @sampleID,
          :minNum => 0
        }
      )

      resp = apiCaller.parseRespBody
      resp["data"].each{|k,v|
        puts resp["data"][k].key?(@sampleID)
        if(k == trackName and resp["data"][k].key?(@sampleID))
          @trackMap[k] = resp["data"][k][@sampleID]
        end
      }
    }
    $stderr.debugPuts(__FILE__, __method__, "INFO" , "parsed #{@numberOfTracks} tracks ")
  end

  ##Final step to make metadata file
  def makeMetaData()
    $stderr.debugPuts(__FILE__, __method__, "INFO" , "BuildMetaData: Starting make metadata ")
    if (@toolExitStatus!=0) then
      $stderr.debugPuts(__FILE__, __method__, "INFO" , "BuildMetaData: skip Starting make metadata ")
      return
    end
    file = File.open("#{@scratch}/metadata.txt","w+")
    file.print "#name"
    @attributesArry.each{|arr|
      file.print "\t#{arr}"
      }
    file.puts

    # CC -> check for empty metadata
    # TODO: in which other ways can LIMMA fail ? luckily at the moment (3/3/12) we are only dealing with
    # one track attribute but this might change
    @emptyAttributeCheck = {}
    @attributesArry.each {|arr|
      @emptyAttributeCheck[arr]=0
    }

    numberOfRows = 0
    @trackMap.each{|k,v|
      if(@metadataHashNew.key?(v))
        ##ALL THE  "_" or ":" should be removed from names.
        ##LIMMA doesnt work on special characters
        newK = k.gsub(/[:| |_]/,'.')
        file.print "#{newK}"
        @attributesArry.each{|arr|
          if(@metadataHashNew[v].key?(arr))
            file.print "\t#{@metadataHashNew[v][arr]}"
          else
            file.print "\tNA"
          end
          }
        numberOfRows += 1
      end
      file.puts
    }
    file.close

    if (@trackMap.keys.size==0 || numberOfRows==0) then
      @toolExitStatus = 121
    end
  end

  def buildMatrix
    $stderr.debugPuts(__FILE__, __method__, "INFO" , "BuildMetaData: Starting map tracks ")
    if (@toolExitStatus!=0) then
      $stderr.debugPuts(__FILE__, __method__, "INFO" , "BuildMetaData: skip Starting map tracks ")
      return
    end
    @missingAttTrks = Hash.new {|k,v| k[v] = []}
    ##Preparing attribute list and number of metadata files accordingly.
    attributeArray = @attributes.split(',')
    bufferString   = ""
    attributeArray.each{|attr|
     # File.open("#{@scratch}/#{CGI.escape(attr)}.metadata" ,"w+")
      attr.strip!
      bufferString <<"#{CGI.escape(attr)},"
      }
    bufferString.chomp!(",")


    ##Mapping between attributes and tracks and building metadata accordingly
    file = File.open("#{@scratch}/tmpFile.txt")
    file.each{|track|
      track.chomp!
      uri  = URI.parse(track)
      uri = URI.parse(track)
      db   = @dbhelper.extractName(track)
      grp  = @grph.extractName(track)
      trk  = @trackhelper.extractName(track)
      host = uri.host
      rcscPath = "/REST/v1/grp/{grp}/db/{db}/trks/attributes/map?attributeList={attrList}&minNumAttributes={minNum}"
      rcscPath << "&gbkey=#{@dbhelper.extractGbKey(track)}" if(@dbhelper.extractGbKey(track))
      apiCaller = WrapperApiCaller.new(host,rcscPath,@userId)
      hr = apiCaller.get(
        {
          :grp => grp,
          :db => db,
          :attrList => bufferString,
          :minNum => 0
        }
      )
      resp = apiCaller.parseRespBody
      puts resp
      resp["data"].each{|k,v|
        if(k == trk)
          ##Finding missing attributes
          availAttr = resp["data"][k].keys
          missingAttr = attributeArray - availAttr
          ##If there are missing attribute in a track, store in a hash, we will let the user know about it
          if(!missingAttr.empty?)
            $stderr.debugPuts(__FILE__, __method__, "Missing Attributes" , "#{trk}->#{missingAttr}")
            missingAttr.each{|attr|
              @missingAttTrks[trk].push(attr)
            }
          else
            $stderr.debugPuts(__FILE__, __method__, "All GOOD" , "#{trk} has all the attributes available")
          end

          ##Create metadata files accordingly
          resp["data"][k].each{|attr, val|
            @metadataHash[k][attr] = val
          }
        end
        }
      }

    fileW = File.open("#{@scratch}/metadata.txt","w+")
    fileW.write "#name"
    attributeArray.each {|attr|
      fileW.write "\t#{attr}"
      }
    fileW.puts
    @metadataHash.each{|k,v|
      newK = k.gsub(/[:| ]/,'.')
      fileW.write newK
      attributeArray.each {|attr|
        if(@metadataHash[k].key?(attr))
          fileW.write "\t#{@metadataHash[k][attr]}"
        else
          fileW.write "\tNA"
        end
        }
      fileW.puts
      }
    fileW.close

    ##Report missing attributes
    fileW = File.open("#{@scratch}/missingAttr.txt","w+")
    @missingAttTrks.each{|k,v|
      fileW.write "#{k}"
      v.each{|attr|
        fileW.write "\t#{attr}"
        }
      fileW.puts
      }
    fileW.close
  end

  #reading samples from the provided db
  def readSamples()
    if (@toolExitStatus!=0) then
      return
    end
    @metadataHashNew   = Hash.new {|k,v| k[v] = Hash.new{|a,b| a[b]= "" }}
    @headers = []
    uri = URI.parse(@db)
    #uri = URI.parse(@db)
    host = uri.host
    path = uri.path
    file = File.open("#{@scratch}/rawMetadata.txt","w+")
    apicaller = WrapperApiCaller.new(host,"",@userId)
    path = "#{path}/samples?format=tabbed"
    path << "&gbKey=#{@dbhelper.extractGbKey(@db)}" if(@dbhelper.extractGbKey(@db))
    apicaller.setRsrcPath(path)
    httpResp = apicaller.get(){|chunck|
      file.write chunck
    }
    file.close
  # Reading downloaded file and building hash of it to make usable one
   file = File.open("#{@scratch}/rawMetadata.txt")
   headerLine = true
   file.each {|line|
     line.strip!
     column = line.split(/\t/)
     if(headerLine)
       @headers = column
     else
       for i in 1 ... @headers.size
        @metadataHashNew[column[0]][@headers[i]] = column[i]
       end
     end
     headerLine = false
     }
  end

  def getToolStatus()
    return @toolExitStatus
  end

  ##help section defined
  def BuildMetadata.usage(msg='')
    unless(msg.empty?)
      puts "\n#{msg}\n"
    end
    puts "
      PROGRAM DESCRIPTION:
        Builds metadata files
      COMMAND LINE ARGUMENTS:
        --trackFile    | -t => track file
        --attributes   | -a => attribute names (comma separated)
        --apiDBRC      | -A => dbrc key
        --scratch      | -s => scratch
        --db           | -d => db
        --sampleID     | -S => sampleID
        --help         | -h => [Optional flag]. Print help info and exit.
      usage:

        ";
      exit;
  end #

  # Process Arguements form the command line input
  def BuildMetadata.processArguements()
    # We want to add all the prop_keys as potential command line options
    optsArray = [
                  ['--trackFile'       ,'-t', GetoptLong::REQUIRED_ARGUMENT],
                  ['--attributes'      ,'-a', GetoptLong::REQUIRED_ARGUMENT],
                  ['--apiDBRC'         ,'-A', GetoptLong::REQUIRED_ARGUMENT],
                  ['--scratch'         ,'-s', GetoptLong::REQUIRED_ARGUMENT],
                  ['--db'              ,'-d', GetoptLong::REQUIRED_ARGUMENT],
                  ['--sampleID'        ,'-S', GetoptLong::REQUIRED_ARGUMENT],
                  ['--userId'        ,'-u', GetoptLong::REQUIRED_ARGUMENT],
                  ['--help'            ,'-H', GetoptLong::NO_ARGUMENT]
                ]
    progOpts = GetoptLong.new(*optsArray)
    BuildMetadata.usage("USAGE ERROR: some required arguments are missing") unless(progOpts.getMissingOptions().empty?)
    optsHash = progOpts.to_hash
    Coverage if(optsHash.empty? or optsHash.key?('--help'));
    return optsHash
  end

end

begin
optsHash = BuildMetadata.processArguements()
performQCUsingFindPeaks = BuildMetadata.new(optsHash)
# $stderr.debugPuts(__FILE__, __method__, "INFO" , "START BuildMetaData #{performQCUsingFindPeaks.getToolStatus()}")
performQCUsingFindPeaks.readSamples()
performQCUsingFindPeaks.mapTracks()
performQCUsingFindPeaks.makeMetaData()
# CC => return tool exit status
$stderr.debugPuts(__FILE__, __method__, "INFO" , "STOP BuildMetaData #{performQCUsingFindPeaks.getToolStatus()}")
exit(performQCUsingFindPeaks.getToolStatus())

rescue => err
      $stderr.puts "Details: #{err.message}"
      $stderr.puts err.backtrace.join("\n")
      exit(121)
end
