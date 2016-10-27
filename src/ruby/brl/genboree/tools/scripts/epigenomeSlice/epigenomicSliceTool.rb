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
    @output    = CGI.escape((optsHash['--output']))
    @scratch   = File.expand_path(optsHash['--scratch'])
    @apiDBRCkey= optsHash['--apiDBRCKey']
    @userId    = optsHash['--userId']
    @reomveNoData = optsHash['--removeNoData']
    @trkNumber = 0
    @attributearray = []

    @gbConfFile     = "/cluster.shared/local/conf/genboree/genboree.config.properties"
    @grph           = BRL::Genboree::REST::Helpers::GroupApiUriHelper.new(@gbConfFile)
    @dbhelper       = BRL::Genboree::REST::Helpers::DatabaseApiUriHelper.new(@gbConfFile)
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
    tmpPath << "?gbKey=#{@dbhelper.extractGbKey(@roitrk)}" if(@dbhelper.extractGbKey(@roitrk))
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
    buildMatrix()
  end

  ##download the tracks
  def withROI()
    tempFile = File.open("#{@scratch}/matrix/tempLM.txt","w+")
    firstTrack = true
    @trkSetHash.each_key{|trackSet|
      $stderr.debugPuts(__FILE__, __method__, "Downloading TRACK",trackSet)
      indexCounter = 0
      kk = @trackhelper.extractName(trackSet)
      newtrk = kk.gsub(/[:| ]/,'.')
      downloadFileName = "#{CGI.escape(kk)}.bedGraph.bz2"
      downloadedFile = @trkApiUriHelper.getDataFileForTrack(trackSet, "bedGraph", @aggFunction, @roitrk, "#{@scratch}/signal-search/trksDownload/#{downloadFileName}", @userId.to_i, nil, "n/a", 5)
      if(downloadedFile)
        $stderr.debugPuts(__FILE__, __method__, "Build Matrix Tool", "Successfully downloaded #{@wtrkName}")
        ## Reading downloaded track file
        fileNewName = "#{@scratch}/signal-search/trksDownload/#{downloadFileName}"
        expanderObj = BRL::Genboree::Helpers::Expander.new("#{@scratch}/signal-search/trksDownload/#{downloadFileName}")
        if(compressed = expanderObj.isCompressed?("#{@scratch}/signal-search/trksDownload/#{downloadFileName}"))
         # fullPathToUncompFile = advancedExpander("#{@scratch}/signal-search/trksDownload/#{File.basename(trackSet)}.bedGraph.bz2" ,"#{@scratch}/signal-search/trksDownload/#{File.basename(trackSet)}.bedGraph", @scratch )
          expanderObj.extract('text')
          fullPathToUncompFile = expanderObj.uncompressedFileName
          fileNewName = File.expand_path(fullPathToUncompFile)
        end
        skipHeader = false
        fileHandle = File.open(fileNewName)
        fileHandle.each_line {|line|
          if(skipHeader)
            line.strip!
            column = line.split(/\t/)
            if(firstTrack)
              tempFile.puts "#{column[0]}_#{column[1]}_#{column[2]}_#{indexCounter}"
            end
            @matixValHash[newtrk][indexCounter] = column[3].to_f
            indexCounter += 1
          end
          skipHeader = true
          }

      else
        $stderr.debugPuts(__FILE__, __method__, "Build Matrix Tool -Error", "Download Failure #{@wtrkName}")
      end
      firstTrack = false
    }
  end

  ##download the ROI track for regions name
  def downloadROI()
    $stderr.debugPuts(__FILE__, __method__, "Downloading ROI",@roitrk)
    downloadFileName = "#{CGI.escape(@trackhelper.extractName(@roitrk))}.bedGraph.bz2"
    downloadedFile = @trkApiUriHelper.getDataFileForTrack(@roitrk, "lff", 'rawdata', "", "#{@scratch}/signal-search/trksDownload/#{downloadFileName}", @userId.to_i, nil, "n/a", 5)
    if(downloadedFile)
      indexCounter = 0
      $stderr.debugPuts(__FILE__, __method__, "Build Matrix Tool", "Successfully downloaded #{@roitrk}")
      ## Reading downloaded track file
      fileNewName = "#{@scratch}/signal-search/trksDownload/#{downloadFileName}"
      expanderObj = BRL::Genboree::Helpers::Expander.new("#{@scratch}/signal-search/trksDownload/#{downloadFileName}")
      if(compressed = expanderObj.isCompressed?("#{@scratch}/signal-search/trksDownload/#{downloadFileName}"))
        expanderObj.extract('text')
        fullPathToUncompFile = expanderObj.uncompressedFileName
        fileNewName = File.expand_path(fullPathToUncompFile)
      end
      fileHandle = File.open(fileNewName)
      fileHandle.each_line {|line|
        line.strip!
        column = line.split(/\t/)
        key = "#{column[4]}_#{column[5].to_i-1}_#{column[6]}_#{indexCounter}"
        @matixNameHash[key] = column[1]
        indexCounter += 1
      }
    else
      $stderr.debugPuts(__FILE__, __method__, "Build Matrix Tool -Error", "Download Failure #{@wtrkName}")
      @exitCode = apicaller.apiStatusObj['statusCode']
    end
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

  # Process Arguements form the command line input
  def EpigenomicSliceTool.processArguements()
    # We want to add all the prop_keys as potential command line options
    optsArray = [
                  ['--trackSet'        ,'-t', GetoptLong::REQUIRED_ARGUMENT],
                  ['--roiTrack'        ,'-r', GetoptLong::OPTIONAL_ARGUMENT],
                  ['--apiDBRCKey'      ,'-a', GetoptLong::OPTIONAL_ARGUMENT],
                  ['--aggFunction'     ,'-A', GetoptLong::REQUIRED_ARGUMENT],
                  ['--userId'          ,'-u', GetoptLong::REQUIRED_ARGUMENT],
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
optsHash = EpigenomicSliceTool.processArguements()
performQCUsingFindPeaks = EpigenomicSliceTool.new(optsHash)
performQCUsingFindPeaks.buildHashofVectorEntity()
rescue => err
      $stderr.puts "Details: #{err.message}"
      $stderr.puts err.backtrace.join("\n")
end
