#!/usr/bin/env ruby

# Load libraries
require 'getoptlong'
require 'brl/util/util'
require 'brl/util/textFileUtil'
require 'brl/genboree/dbUtil'
require 'brl/genboree/abstract/resources/track'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/genboreeDBHelper'
require 'brl/genboree/lockFiles/genericDbLockFile'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/rest/helpers/groupApiUriHelper'
require 'brl/genboree/tools/scripts/uploadTrackAnnos/uploadTrackAnnosWrapper'
require 'uri'
require 'json'
ENV['DBRC_FILE']
ENV['PATH']
require 'brl/genboree/rest/wrapperApiCaller'
include BRL::Genboree::REST

# Class for copying tracks from one db to another in Genboree.
# Note that the tool can take multiple input tracks and the tracks can be from different database
class TrackCopier

  # Constructor
  # [+optsHash+] hash with command line options
  # [+returns+] nil
  def initialize(optsHash)
    @inputFile = optsHash['--inputFile']
    @dbrcKey = optsHash['--dbrcKey']
    @userId = optsHash['--userId']
    @deleteSourceTrack = optsHash['--deleteSourceTrack']
    @scratchDir = optsHash['--scratchDir']
    @userLogin = optsHash['--userLogin']
    @jobId = optsHash['--jobId'] || 0
    # Put the rest of the stuff in a begin rescue block so that we can 'handle' if anything goes wrong
    begin
      @dbApiHelper = BRL::Genboree::REST::Helpers::DatabaseApiUriHelper.new()
      initDefaultFeatures() # Initialize features that will be set if user is admin
      parseInputFile(@inputFile) # Get the input and output info
      copyTracks() # Download the tracks and then upload them one by one making API calls
    rescue Exception => err
      displayErrorMsgAndExit(err)
    end
    $stderr.puts "All done"
    exit(0)
  end

  # Downloads and uploads tracks to the user specified database
  # [+returns+] nil
  def copyTracks()
    # First make sure we have a valid key to make API calls
    genbConf = ENV['GENB_CONFIG']
    genbConfig = BRL::Genboree::GenboreeConfig.load(genbConf)
    dbrcFile = File.expand_path(ENV['DBRC_FILE'])
    if(@dbrcKey)
      dbrc = BRL::DB::DBRC.new(dbrcFile, @dbrcKey)
      # get super user, pass and hostname
      @user = dbrc.user
      @pass = dbrc.password
    else
      suDbDbrc = BRL::Genboree::GenboreeUtil.getSuperuserDbrc(genbConfig, dbrcFile)
      @user = suDbDbrc.user
      @pass = suDbDbrc.password
    end
    # Get role of user in output group
    grpHelperObj = BRL::Genboree::REST::Helpers::GroupApiUriHelper.new()
    aliasOutputDb = ApiCaller.applyDomainAliases(@outputDb)
    groupUri = grpHelperObj.extractPureUri(aliasOutputDb)
    role = ""
    grpUri = URI.parse(groupUri)
    rsrcPath = "#{grpUri.path.chomp("?")}/usr/#{@userLogin}/role?"
    rsrcPath << "gbKey=#{grpHelperObj.extractGbKey(@outputDb)}" if(grpHelperObj.extractGbKey(@outputDb))
    apiCaller = WrapperApiCaller.new(grpUri.host, rsrcPath, @userId)
    apiCaller.get()
    if(!apiCaller.succeeded?)
      raise "ApiCaller Failed: #{apiCaller.respBody.inspect}"
    end
    retVal = apiCaller.parseRespBody()
    role = retVal['data']['role']

    # loop over all tracks
    @inputTracks.each { |track|
      uri = URI.parse(track)
      trkRsrcPath = rcscPath = uri.path
      host = uri.host
      rcscPath.gsub!("?", "")

      # Get the gbKey from the track URI, if present
      # - [once, preferably; original code does this over and over in various scattered places in the code]
      srcTrkGbKey = grpHelperObj.extractGbKey(track)

      # Get the class for this source track
      # - used to set the destination track class ONLY IF it doesn't already exist
      srcTrkClass = getTrackClass(host, rcscPath, srcTrkGbKey)
      $stderr.debugPuts(__FILE__, __method__, "DEBUG", "srcTrkClass: #{srcTrkClass.inspect}")

      # Get all attributes, also check if any track is HDHV
      rsrcPath = "#{rcscPath}/attributes?"
      rsrcPath << "gbKey=#{srcTrkGbKey}" if(srcTrkGbKey)
      apiCaller = WrapperApiCaller.new(host, rsrcPath, @userId)
      apiCaller.get()
      resp = apiCaller.parseRespBody()
      attHash = {}
      resp['data'].each { |attribute|
        attHash[attribute['text']] = nil
      }
      attHash.each_key { |attr|
        rsrcPath = "#{rcscPath}/attribute/#{CGI.escape(attr)}/value?"
        rsrcPath << "gbKey=#{srcTrkGbKey}" if(srcTrkGbKey)
        apiCaller = WrapperApiCaller.new(host, rsrcPath, @userId)
        apiCaller.get()
        response = apiCaller.parseRespBody
        attHash[attr] = response['data']['text']
      }

      # Get track features; style, colors, display, etc
      getTrackFeatures(role, host, rcscPath, track)

      trkHelperObj = BRL::Genboree::REST::Helpers::TrackApiUriHelper.new()
      downloadFormat = attHash['gbTrackRecordType'] ? "fwig" : "lff"
      trackName = "#{trkHelperObj.lffType(track)}:#{trkHelperObj.lffSubtype(track)}"

      # Download the annos
      fileName = "#{@scratchDir}/#{Time.now.to_f}.#{downloadFormat}"
      fWriter = File.open(fileName, "w")
      rsrcPath = "#{rcscPath}/annos?format=#{downloadFormat}"
      rsrcPath << "&gbKey=#{srcTrkGbKey}" if(srcTrkGbKey)
      apiCaller = WrapperApiCaller.new(host, rsrcPath, @userId)
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Downloading #{downloadFormat.inspect} track: #{track}")
      apiCaller.get() {|chunk| fWriter.print(chunk)}
      raise "ApiCaller Failed: #{apiCaller.respBody.inspect}" if(!apiCaller.succeeded?)
      fWriter.close()

      # First check if the destination track already exists
      uploadAnnosObj = BRL::Genboree::Tools::Scripts::UploadTrackAnnosWrapper.new()
      outputUri = URI.parse(@outputDb)
      destHost = outputUri.host
      destUri = outputUri.path
      destUri.gsub!("?", "")
      destUri << "/trk/#{CGI.escape(trackName)}"
      rsrcPath = "#{destUri}?"
      rsrcPath << "&gbKey=#{grpHelperObj.extractGbKey(@outputDb)}" if(grpHelperObj.extractGbKey(@outputDb))
      apiCaller = WrapperApiCaller.new(destHost, rsrcPath, @userId)
      apiCaller.get()
      $stderr.debugPuts(__FILE__, __method__, "DEBUG", "Getting '#{destUri.inspect}' resulted in:\n\n#{apiCaller.respBody}\n\n")

      @trackExists = false
      # Now make an empty track into the new database, if it does not exist
      if(!apiCaller.succeeded?) # Track does not exist, add it
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Track does not exist in target database.")
        # Do we need to make the track ahead of time and set the class argument?
        unless(downloadFormat == "lff") # not for LFF...records have class and other stuff
          $stderr.debugPuts(__FILE__, __method__, "STAUTS", "Need to create high-density track and put in some of the custom attributes")
          rsrcPath << "&trackClassName={className}"
          apiCaller.setRsrcPath(rsrcPath)
          #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "apiCaller for create:\n\n#{apiCaller.inspect}")
          apiCaller.put({:className => srcTrkClass})
          if(apiCaller.succeeded?)
            # Set all the track attributes.
            attHash.each_key { |attName|
              payload = {"data" => {"text" => "#{attHash[attName]}"}}
              rsrcPath = "#{destUri}/attribute/{attName}/value?"
              rsrcPath << "gbKey=#{grpHelperObj.extractGbKey(@outputDb)}" if(grpHelperObj.extractGbKey(@outputDb))
              apiCaller = WrapperApiCaller.new(destHost, rsrcPath, @userId)
              apiCaller.put({:attName => "#{attName}"}, payload.to_json)
              $stderr.puts "ApiCaller Failed: #{apiCaller.respBody.inspect}\nattribute: #{attName.inspect}\tvalue: #{attHash[attName].inspect}" if(!apiCaller.succeeded?)
            }
          else
            raise "Could not create empty track. #{apiCaller.respBody.inspect}" if(!apiCaller.succeeded?)
          end
        end
      else # track exists
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Track already exists in target database. We will not mess with attributes nor classes, just add annos from source.")
        @trackExists = true
      end

      # Now upload the annos
      featureUri = destUri.dup()
      destUri.gsub!("/trk/#{CGI.escape(trackName)}", "/annos?")
      # Get the refseqid of the target database
      outputUri = URI.parse(@outputDb)
      rsrcUri = outputUri.path
      rsrcUri << "?gbKey=#{@dbApiHelper.extractGbKey(@outputDb)}" if(@dbApiHelper.extractGbKey(@outputDb))
      apiCaller = WrapperApiCaller.new(outputUri.host, rsrcUri, @userId)
      apiCaller.get()
      resp = JSON.parse(apiCaller.respBody)
      uploadAnnosObj = BRL::Genboree::Tools::Scripts::UploadTrackAnnosWrapper.new()
      uploadAnnosObj.refSeqId = resp['data']['refSeqId']
      uploadAnnosObj.groupName = grpHelperObj.extractName(@outputDb)
      uploadAnnosObj.userId = @userId
      uploadAnnosObj.jobId = @jobId
      uploadAnnosObj.trackName = trackName
      uploadAnnosObj.outputs = [@outputDb]
      begin
        if(downloadFormat == 'lff')
          uploadAnnosObj.uploadLff(CGI.escape(File.expand_path(fileName)), false)
        else
          uploadAnnosObj.uploadWig(CGI.escape(File.expand_path(fileName)), false)
        end
      rescue => uploadErr
        $stderr.puts "Error: #{uploadErr}"
        $stderr.puts "Error Backtrace:\n\n#{uploadErr.backtrace.join("\n")}"
        errMsg = "FATAL ERROR: Could not upload track to target database."
        if(uploadAnnosObj.outFile and File.exists?(uploadAnnosObj.outFile))
          errMsg << "\n\n#{File.read(uploadAnnosObj.outFile)}"
        end
        raise errMsg
      end
      `rm -f #{fileName}`
      # Set the track features(style, color, etc) if admin
      # If not admin only set style and color
      if(!@trackExists)
        if(role == 'administrator')
          @defaultFeatures.each_key { |feature|
            value = nil
            value = @defaultFeatures[feature]
            $stderr.puts "Setting feature: #{feature.inspect} with value: #{value.inspect}"
            if(feature == 'links')
              if(!value.nil? and !value.empty?)
                rsrcPath = "#{featureUri}/#{feature}?"
                rsrcPath << "gbKey=#{grpHelperObj.extractGbKey(@outputDb)}" if(grpHelperObj.extractGbKey(@outputDb))
                apiCaller = WrapperApiCaller.new(destHost, rsrcPath, @userId)
                apiCaller.put(@defaultFeatures[feature].to_json)
                $stderr.puts "ApiCaller Failed: #{apiCaller.respBody.inspect}\nFeature: #{feature.inspect}\tvalue: #{value.inspect}" if(!apiCaller.succeeded?)
              end
            elsif(feature == 'defaultRank')
              if(!value.nil? and !value['text'].nil? and value['text'].to_s.strip =~ /^\d+$/)
                rsrcPath = "#{featureUri}/#{feature}?"
                rsrcPath << "gbKey=#{grpHelperObj.extractGbKey(@outputDb)}" if(grpHelperObj.extractGbKey(@outputDb))
                apiCaller = WrapperApiCaller.new(destHost, rsrcPath, @userId)
                apiCaller.put(@defaultFeatures[feature].to_json)
                $stderr.puts "ApiCaller Failed: #{apiCaller.respBody.inspect}\nFeature: #{feature.inspect}\tvalue: #{value.inspect}" if(!apiCaller.succeeded?)
              end
            else
              if(!value.nil? and !value.empty? and !value['text'].nil? and !value['text'].empty?)
                rsrcPath = "#{featureUri}/#{feature}?"
                rsrcPath << "gbKey=#{grpHelperObj.extractGbKey(@outputDb)}" if(grpHelperObj.extractGbKey(@outputDb))
                apiCaller = WrapperApiCaller.new(destHost, rsrcPath, @userId)
                apiCaller.put(@defaultFeatures[feature].to_json)
                $stderr.puts "ApiCaller Failed: #{apiCaller.respBody.inspect}\nFeature: #{feature.inspect}\tvalue: #{value.inspect}" if(!apiCaller.succeeded?)
              end
            end
          }
        else
          features = ['defaultStyle','defaultColor']
          features.each { |feature|
            value = nil
            value = @defaultFeatures[feature]
            if(!value.nil? and !value.empty? and !value['text'].nil? and !value['text'].empty?)
              rsrcPath = "#{featureUri}/#{feature}?"
              rsrcPath << "gbKey=#{grpHelperObj.extractGbKey(@outputDb)}" if(grpHelperObj.extractGbKey(@outputDb))
              apiCaller = WrapperApiCaller.new(destHost, rsrcPath, @userId)
              apiCaller.put(@defaultFeatures[feature].to_json)
              $stderr.puts "ApiCaller Failed: #{apiCaller.respBody.inspect}\nFeature: #{feature.inspect}\tvalue: #{value.inspect}" if(!apiCaller.succeeded?)
            end
          }
        end
      end

      # Delete source track, if required
      if(@deleteSourceTrack)
        rsrcPath = "#{rcscPath}?"
        rsrcPath << "gbKey=#{grpHelperObj.extractGbKey(track)}" if(grpHelperObj.extractGbKey(track))
        apiCaller = WrapperApiCaller.new(host, rsrcPath, @userId)
        apiCaller.delete()
        $stderr.puts "ApiCaller Failed: #{apiCaller.respBody.inspect}" if(!apiCaller.succeeded?)
      end
    }
  end

  # Initializes default features Hash (used if user is admin)
  # [+returns+] nil
  def initDefaultFeatures()
    @defaultFeatures = {
                          "defaultStyle" => {},
                          "defaultColor" => {},
                          "defaultDisplay" => {},
                          "defaultRank" => {},
                          "description" => {},
                          "url" => {},
                          "urlLabel" => {},
                          "links" => {}
                        }
  end


  # Get the first class the source track is found in, so we
  #   can attempt to put it in the correct class in the destination
  #   ratherh than some arbitrary hard-coded default.
  # @param [String] host The host with the src track
  # @param [String] trkRsrcPath The path to the source track
  # @param [String,nil] gbKey The gbKey to use with the source track, if any
  # @return [String] the first class found for the track
  def getTrackClass(host, trkRsrcPath, gbKey=nil)
    retVal = nil
    rsrcPath = "#{trkRsrcPath}/classes"
    rsrcPath << "?gbKey=#{gbKey}" if(gbKey)
    apiCaller = WrapperApiCaller.new(host, rsrcPath, @userId)
    apiCaller.get()
    if(!apiCaller.succeeded?)
      raise "ApiCaller Failed: #{apiCaller.respBody.inspect}"
    else
      $stderr.debugPuts(__FILE__, __method__, "DEBUG", "Classes for #{rsrcPath.inspect}:\n\n#{apiCaller.respBody.inspect}\n\n")
      apiCaller.parseRespBody()
      retVal = apiCaller.apiDataObj.first["text"]
    end
    return retVal
  end

  # Gets track styles, colors, etc
  # [+role+] role in output group
  # [+host+] server
  # [+rcscPath+] resource API path
  # [+returns+] nil
  def getTrackFeatures(role, host, rcscPath, track)
    @defaultFeatures.each_key { |feature|
      rsrcPath = "#{rcscPath}/#{feature}?"
      rsrcPath << "gbKey=#{@dbApiHelper.extractGbKey(track)}" if(@dbApiHelper.extractGbKey(track))
      apiCaller = WrapperApiCaller.new(host, rsrcPath, @userId)
      apiCaller.get()
      if(!apiCaller.succeeded?)
        raise "ApiCaller Failed: #{apiCaller.respBody.inspect}"
      end
      apiCaller.parseRespBody
      @defaultFeatures[feature] = apiCaller.apiDataObj
    }
  end

  # [+inputFile+] file with input and output info
  # [+returns+] nil
  def parseInputFile(inputFile)
    fReader = File.open(inputFile, "r")
    fReader.each_line { |line|
      line.strip!
      next if(line.nil? or line.empty? or line =~ /^#/ or line =~ /^\s*$/)
      if(line =~ /^input/)
        line.gsub!("inputTracks=", "")
        @inputTracks = line.split(",")
      elsif(line =~ /^output/)
        line.gsub!("outputDatabase=", "")
        @outputDb = line
      else
        next
      end
    }
    raise "No Input Tracks specified in input file" if(@inputTracks.nil? or @inputTracks.empty?)
    raise "No Output Database specified in input file" if(@outputDb.nil? or @outputDb.empty?)
  end

  # Displays error message and quits
  # [+msg+]  error message
  #  [+returns+] nil
  def displayErrorMsgAndExit(msg)
    $stderr.puts "ERROR:\n#{msg}"
    $stdout.puts "ERROR:\n#{msg}"
    $stderr.puts "ERROR Backtrace:\n\n#{msg.backtrace.join("\n")}"
    exit(14)
  end

end

# Class for running the script and parsing args
class RunScript

  VERSION_NUMBER="1.0"
  DEFAULTUSAGEINFO="

  Author: Sameer Paithankar

  Description: This tool is used for for downloading annotations for a list of tracks and then uploading them into a new database

  Notes: Intended to be called via the Genboree Workbench, by the trackCopierWrapper.rb script
  => The input file needs to be a properties file with 2 records: inputTracks and outputDatabase
  => Both of these needs to be full REST URIs

  For example, the file could look like:
  inputTracks=http:\/\/10.15.7.29\/REST\/v1\/grp\/EDACC%20-%20Test%20New%20Features\/db\/newSchemaForBlock\/trk\/Gene%3ARefSeq?,http:\/\/10.15.7.29\/REST\/v1\/grp\/EDACC%20-%20Test%20New%20Features\/db\/newSchemaForBlock\/trk\/Cyto%3ABand?
  outputDatabase=http:\/\/10.15.7.29\/REST\/v1\/grp\/EDACC%20-%20Test%20New%20Features\/db\/newSchemaForBlock?
    -i  --inputFile                     => input file (required)
    -k  --dbrcKey                       => dbrcKey to make API calls (optional)
    -u  --userId                        => Genboree userid (This is used to send emails back to the user) (required)
    -l  --userLogin                     => Genboree userlogin (required)
    -d  --deleteSourceTrack
    -s  --scratchDir                    => optional (will use pwd if not provided)
    -v  --version                       => Version of the program
    -h  --help                          => Display help

    Usage: ruby trackCopier.rb -i file.txt

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
    optsArray=[
      ['--inputFile','-i',GetoptLong::REQUIRED_ARGUMENT],
      ['--dbrcKey','-k',GetoptLong::OPTIONAL_ARGUMENT],
      ['--userId','-u',GetoptLong::REQUIRED_ARGUMENT],
      ['--userLogin','-l',GetoptLong::REQUIRED_ARGUMENT],
      ['--deleteSourceTrack','-d',GetoptLong::OPTIONAL_ARGUMENT],
      ['--scratchDir','-s',GetoptLong::OPTIONAL_ARGUMENT],
      ['--jobId','-j',GetoptLong::OPTIONAL_ARGUMENT],
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

  def self.performTrackCopier(optsHash)
    trackCopierObj = TrackCopier.new(optsHash)
  end

end

optsHash = RunScript.parseArgs()
RunScript.performTrackCopier(optsHash)
