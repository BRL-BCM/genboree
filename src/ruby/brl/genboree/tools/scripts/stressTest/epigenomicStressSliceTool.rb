#!/usr/bin/env ruby
require 'json'
require 'fileutils'
require 'cgi'
require 'brl/util/util'
require 'brl/util/emailer'
require 'gsl'
require 'brl/genboree/rest/wrapperApiCaller'
require 'brl/genboree/helpers/expander'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'

include GSL
include BRL::Genboree::REST

class EpigenomicSliceTool

  def initialize(optsHash)
    @trackSet  = optsHash['--trackSet']
    @roitrk    = optsHash['--roiTrack']
    @aggFunction= optsHash['--aggFunction']
    @output    = optsHash['--output']
    @scratch   = File.expand_path(optsHash['--scratch'])
    @apiDBRCkey= optsHash['--apiDBRCKey']
    @userId    = optsHash['--userId']
    @hostAuthMap = Abstraction::User.getHostAuthMapForUserId(nil, @userId)
    @reomveNoData = optsHash['--removeNoData']
    @trkNumber = 0
    @output = optsHash['--output']
    @jobId = optsHash['--jobId']
    @attributearray = []
    @gbConfFile     = "/cluster.shared/local/conf/genboree/genboree.config.properties"
    @grph           = BRL::Genboree::REST::Helpers::GroupApiUriHelper.new(@gbConfFile)
    @dbApiUriHelper       = BRL::Genboree::REST::Helpers::DatabaseApiUriHelper.new(@gbConfFile)
    @trackhelper    = BRL::Genboree::REST::Helpers::TrackApiUriHelper.new(@gbConfFile)

    dbrc 	    = BRL::DB::DBRC.new(nil, @apiDBRCkey)
    @pass 	    = dbrc.password
    @user 	    = dbrc.user

    uri             = URI.parse(@roitrk)
    @rPath          = uri.path.chomp('?')
    @host           = uri.host

    @trkSetHash     = {}
    @matixNameHash  = {}
    @trkApiUriHelper = BRL::Genboree::REST::Helpers::TrackApiUriHelper.new()
    system("mkdir -p #{@scratch}/matrix")
    #@matixValHash  = Hash.new {|hash,key| hash[key] =GSL::Vector.alloc(10)}
  end


  ##initializing gsl vector and making hash of vectors. This one uses ENTITY LIST as input
  def buildHashofVectorEntity()
    fileHandle = File.open(@trackSet)
    fileHandle.each{|line|
      line.strip!
      @trkSetHash[line] = ""
    }
    fileHandle.close
    #File.delete("#{@scratch}/tmpFile1.txt")
    #File.delete("#{@scratch}/tmpFile2.txt")

    tmpPath = "#{@rPath}/annos/count"
    tmpPath << "?gbKey=#{@dbApiUriHelper.extractGbKey(@roitrk)}" if(@dbApiUriHelper.extractGbKey(@roitrk))
    apicaller = WrapperApiCaller.new(@host,tmpPath,@userId)
    apicaller.get()
    if apicaller.succeeded?
      $stderr.debugPuts(__FILE__, __method__, "Build Matrix Tool", "downloaded count of the ROI track")
    else
      $stderr.debugPuts(__FILE__, __method__, "Build Matrix Tool -Error", "#{apicaller.parseRespBody().inspect}")
      @exitCode = apicaller.apiStatusObj['statusCode']
    end
    temp = apicaller.parseRespBody
    @noOfPoints = temp["data"]["count"].to_i
    $stderr.debugPuts(__FILE__, __method__, "Build Matrix Tool", "counts of the ROI track #{@noOfPoints}")
    @refLMHash     = GSL::Vector.alloc(@noOfPoints)
    @matixValHash  = Hash.new {|hash,key| hash[key] =GSL::Vector.alloc(@noOfPoints)}
    system("cd #{@scratch}/signal-search/trksDownload")
    downloadROI()
    withROI()
   # buildMatrix()
  end

  ##download the tracks
  def withROI()
    @exitCode = 0
    @trkSetHash.each_key{|trackSet|
      $stderr.debugPuts(__FILE__, __method__, "Downloading TRACK",trackSet)
      roiHost = @trkApiUriHelper.extractHost(@roitrk)
      rsrcPath = "#{@trkApiUriHelper.extractPath(@roitrk)}/annos?format=bedGraph&#{URI.parse(@roitrk).query}&scoreTrack={scrTrack}&spanAggFunction={aggFunction}&emptyScoreValue={esValue}"
      apiCaller = BRL::Genboree::REST::ApiCaller.new(roiHost,rsrcPath, @hostAuthMap)
      scrFileName = CGI.escape(@trkApiUriHelper.extractName(trackSet))
      scrFile = File.open(scrFileName,"w")
      apiCaller.get({:scrTrack=>trackSet,:aggFunction=> @aggFunction,:esValue=>0}){ |chunk| scrFile.print(chunk) }
      scrFile.close()
      if(apiCaller.succeeded?) then
        $stderr.debugPuts(__FILE__, __method__, "Stress Test Tool", "Successfully downloaded #{trackSet}")
        outScrFileName = "#{@jobId}-#{scrFileName}"
        system("bedGraphToFixedWig.rb -i #{CGI.escape(scrFileName)} -o #{CGI.escape(outScrFileName)}")
        $stderr.debugPuts(__FILE__, __method__, "Stress Test Tool", "Successfully created #{outScrFileName}")
        host = @dbApiUriHelper.extractHost(@output)
        rsrcPath = "#{@dbApiUriHelper.extractPath(@output)}/annos?format=wig&trackName={trk}&#{URI.parse(@output).query}"
        apiCaller2 = BRL::Genboree::REST::ApiCaller.new(host,rsrcPath, @hostAuthMap)
        outScrFile = File.open(outScrFileName,"r")
        apiCaller2.put({:trk=>"#{@jobId}-#{@trkApiUriHelper.extractName(trackSet)}"},outScrFile)
        if(apiCaller2.succeeded?) then
          $stderr.debugPuts(__FILE__, __method__, "Stress Test Tool", "Successfully uploaded #{outScrFileName}")
          rsrcPath = "#{@trkApiUriHelper.extractPath(trackSet)}?ooMaxDetailed=true&#{URI.parse(trackSet).query}"
          apiCaller3 = BRL::Genboree::REST::ApiCaller.new(@trkApiUriHelper.extractHost(trackSet),rsrcPath, @hostAuthMap)
          apiCaller3.get
          if(apiCaller3.succeeded?) then
            $stderr.debugPuts(__FILE__, __method__, "Stress Test Tool", "Successfully obtained detailed info #{trackSet}\n\n#{apiCaller3.respBody.inspect}\n\n")
          else
            $stderr.debugPuts(__FILE__, __method__, "Stress Test Tool -Error", "Detailed info Failure #{trackSet}\n#{apiCaller3.respBody.inspect}")
            @exitCode = apiCaller3.apiStatusObj['statusCode']
          end
        else
          $stderr.debugPuts(__FILE__, __method__, "Stress Test Tool -Error", "Upload Failure #{outScrFileName}\n#{apiCaller2.respBody.inspect}")
          @exitCode = apiCaller2.apiStatusObj['statusCode']
        end
      else
        $stderr.debugPuts(__FILE__, __method__, "Stress Test Tool -Error", "Download Failure #{@roitrk}\n#{apiCaller.respBody.inspect}")
        @exitCode = apiCaller.apiStatusObj['statusCode']
      end
    }
      return @exitCode
    end

    ##download the ROI track for regions name
    def downloadROI()
      @exitCode = 0
      $stderr.debugPuts(__FILE__, __method__, "Downloading ROI",@roitrk)
      roiHost = @trkApiUriHelper.extractHost(@roitrk)
      rsrcPath = "#{@trkApiUriHelper.extractPath(@roitrk)}/annos?format=LFF&#{URI.parse(@roitrk).query}"
      apiCaller = BRL::Genboree::REST::ApiCaller.new(roiHost,rsrcPath, @hostAuthMap)
      roiFileName = CGI.escape(@trkApiUriHelper.extractName(@roitrk))
      roiFile = File.open(roiFileName,"w")
      apiCaller.get(){ |chunk| roiFile.print(chunk) }
      roiFile.close()
      if(apiCaller.succeeded?) then
        $stderr.debugPuts(__FILE__, __method__, "Stress Test Tool", "Successfully downloaded #{@roitrk}")
        inRoiFile = File.open(roiFileName,"r")
        outRoiFileName = "#{@jobId}-#{roiFileName}"
        outRoiFile = File.open(outRoiFileName,"w")
        inRoiFile.each_line {|line|
          sl = line.chomp.split(/\t/)
          sl[2] = "#{@jobId}-#{sl[2]}"
          outRoiFile.puts(sl.join("\t"))
        }
        inRoiFile.close
        outRoiFile.close
        $stderr.debugPuts(__FILE__, __method__, "Stress Test Tool", "Successfully created #{outRoiFileName}")
        host = @dbApiUriHelper.extractHost(@output)
        rsrcPath = "#{@dbApiUriHelper.extractPath(@output)}/annos?format=lff&#{URI.parse(@output).query}"
        apiCaller2 = BRL::Genboree::REST::ApiCaller.new(host,rsrcPath, @hostAuthMap)
        outRoiFile = File.open(outRoiFileName,"r")
        apiCaller2.put(outRoiFile)
        if(apiCaller2.succeeded?) then
          $stderr.debugPuts(__FILE__, __method__, "Stress Test Tool", "Successfully uploaded #{outRoiFileName}")
          rsrcPath = "#{@trkApiUriHelper.extractPath(@roitrk)}?ooMaxDetailed=true&#{URI.parse(@roitrk).query}"
          apiCaller3 = BRL::Genboree::REST::ApiCaller.new(roiHost,rsrcPath, @hostAuthMap)
          apiCaller3.get
          if(apiCaller3.succeeded?) then
            $stderr.debugPuts(__FILE__, __method__, "Stress Test Tool", "Successfully obtained detailed info #{@roitrk}\n\n#{apiCaller3.respBody.inspect}\n\n")
          else
            $stderr.debugPuts(__FILE__, __method__, "Stress Test Tool -Error", "Detailed info Failure #{rsrcPath}\n#{apiCaller3.respBody.inspect}")
            @exitCode = apiCaller3.apiStatusObj['statusCode']
          end
        else
          $stderr.debugPuts(__FILE__, __method__, "Stress Test Tool -Error", "Upload Failure #{outRoiFileName}\n#{apiCaller2.respBody.inspect}")
          @exitCode = apiCaller2.apiStatusObj['statusCode']
        end
      else
        $stderr.debugPuts(__FILE__, __method__, "Stress Test Tool -Error", "Download Failure #{@roitrk}\n#{apiCaller.respBody.inspect}")
        @exitCode = apiCaller.apiStatusObj['statusCode']
      end
      return @exitCode
    end

    ##building matrix
    def buildMatrix()
      saveFile = File.open("#{@scratch}/matrix/matrix.xls","w+")
      saveFile2 = File.open("#{@scratch}/matrix/matrix_Original.xls","w+")
      saveFile.print "Index"
      saveFile2.print "Index"
      @trkSetHash.each_key{|k|
        kk = @trackhelper.extractName(k)
        kk = kk.gsub(/[:| ]/,'.')
        saveFile.print "\t#{kk}"
        saveFile2.print "\t#{kk}"
      }
      saveFile.puts
      saveFile2.puts
      lmHandler = File.open("#{@scratch}/matrix/tempLM.txt")
      counter = 0
      lmHandler.each {|line|
        line.strip!
        removeArray = []
        removeBuffer = ""
        @trkSetHash.each_key{|k|
          kk = @trackhelper.extractName(k)
          kk = kk.gsub(/[:| ]/,'.')
          if(@reomveNoData == "true")
            removeArray.push(@matixValHash[kk][counter])
          end
          removeBuffer << "\t#{@matixValHash[kk][counter]}"
        }
        if(@reomveNoData == "true")
          if(removeArray.uniq.size != 1)
            saveFile.print "#{@matixNameHash[line]}"
            saveFile.print "#{removeBuffer}"
            saveFile.puts
            saveFile2.print "#{line}_#{counter}"
            saveFile2.print "#{removeBuffer}"
            saveFile2.puts
          end
        else
          saveFile.print  "#{@matixNameHash[line]}"
          saveFile.print "#{removeBuffer}"
          saveFile.puts
          saveFile2.print  "#{line}_#{counter}"
          saveFile2.print "#{removeBuffer}"
          saveFile2.puts
        end
        counter += 1
      }
      saveFile.close
      saveFile2.close
    end


    ##help section defined
    def EpigenomicSliceTool.usage(msg='')
      unless(msg.empty?)
        puts "\n#{msg}\n"
      end
      puts "
      PROGRAM DESCRIPTION:
      epigenome data matrix builder
      COMMAND LINE ARGUMENTS:
      --trackSet     | -t => entitytrackSet(s) (comma separated)
      --roiTrack     | -r => roi track
      --apiDBRCKey   | -a => dBRC key
      --aggFunction  | -A => agg function
      --scratch      | -S => scratch area
      --userId       | -u => user Id
      --removeNoData | -R => remove no data region (true|false)
      --help         | -h => [Optional flag]. Print help info and exit.
      usage:

      ";
      exit;
    end #

    # Process Arguments form the command line input
    def EpigenomicSliceTool.processArguments()
      # We want to add all the prop_keys as potential command line options
      optsArray = [
        ['--trackSet'        ,'-t', GetoptLong::REQUIRED_ARGUMENT],
        ['--roiTrack'        ,'-r', GetoptLong::OPTIONAL_ARGUMENT],
        ['--apiDBRCKey'      ,'-a', GetoptLong::OPTIONAL_ARGUMENT],
        ['--aggFunction'     ,'-A', GetoptLong::REQUIRED_ARGUMENT],
        ['--userId'          ,'-u', GetoptLong::REQUIRED_ARGUMENT],
        ['--output'    ,'-o', GetoptLong::REQUIRED_ARGUMENT],
        ['--jobId'    ,'-j', GetoptLong::REQUIRED_ARGUMENT],
        ['--scratch'         ,'-S', GetoptLong::REQUIRED_ARGUMENT],
        ['--removeNoData'    ,'-R', GetoptLong::REQUIRED_ARGUMENT],
        ['--help'            ,'-H', GetoptLong::NO_ARGUMENT]
      ]
      progOpts = GetoptLong.new(*optsArray)
      EpigenomicSliceTool.usage("USAGE ERROR: some required arguments are missing") unless(progOpts.getMissingOptions().empty?)
      optsHash = progOpts.to_hash
      Coverage if(optsHash.empty? or optsHash.key?('--help'));
      return optsHash
    end

  end

  begin
    optsHash = EpigenomicSliceTool.processArguments()
    performQCUsingFindPeaks = EpigenomicSliceTool.new(optsHash)
    performQCUsingFindPeaks.buildHashofVectorEntity()
  rescue => err
    $stderr.puts "Details: #{err.message}"
    $stderr.puts err.backtrace.join("\n")
  end
