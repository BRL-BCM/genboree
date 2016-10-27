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

class GeneElementDataSlice

  def initialize(optsHash)
    @trackSet  = File.expand_path(optsHash['--trackSet'])
    @geneList  = File.expand_path(optsHash['--geneList'])
    @scratch   = File.expand_path(optsHash['--scratch'])
    @apiDBRCkey= optsHash['--apiDBRCKey']
    @reomveNoData = optsHash['--removeNoData']
    @userId       = optsHash['--userId']
    @trkNumber = 0
    @attributearray = []

    @gbConfFile     = "/cluster.shared/local/conf/genboree/genboree.config.properties"
    @grph           = BRL::Genboree::REST::Helpers::GroupApiUriHelper.new(@gbConfFile)
    @dbhelper       = BRL::Genboree::REST::Helpers::DatabaseApiUriHelper.new(@gbConfFile)
    @trackhelper    = BRL::Genboree::REST::Helpers::TrackApiUriHelper.new(@gbConfFile)

    dbrc 	    = BRL::DB::DBRC.new(nil, @apiDBRCkey)
    @pass 	    = dbrc.password
    @user 	    = dbrc.user

    @trkSetHash     = {}
    @matixNameHash  = {}
    @trkApiUriHelper = BRL::Genboree::REST::Helpers::TrackApiUriHelper.new()
    system("mkdir -p #{@scratch}/matrix")
    #@matixValHash  = Hash.new {|hash,key| hash[key] =GSL::Vector.alloc(10)}
    @apiCaller = WrapperApiCaller.new("genboree.org","/REST/v1/grp/ROI%20Repository/db/ROI%20Repository%20-%20hg19/trk/GeneModel%3AFull/annos?gbkey=7it9oeuv&format={format}&scoreTrack={scrTrackPath}&nameFilter={name}&emptyScoreValue={esValue}",@userId)
  end


  ##Reading gene list and buildig hash of it
  def readGeneList()
    @geneHash = {}
    fileHandle = File.open(@geneList)
    fileHandle.each{|line|
      @geneHash[line.chomp] = ""
      }
    fileHandle.close
  end


  ##initializing gsl vector and making hash of vectors. This one uses ENTITY LIST as input
  def buildHashofVectorEntity()
    @geneCorHash = {}
    fileHandle = File.open(@trackSet)
    fileHandle.each{|line|
      line.strip!
      @trkSetHash[line] = ""
      }
    fileHandle.close

    ##Know the size of vector beforehand, donwload all the genes for one track
    vectorLength = 0
    @geneHash.each_key {|gene|
      @apiCaller.get({:format => "lff", :scrTrackPath =>@trkSetHash.keys[0],:name => gene, :esValue => 0})
      if @apiCaller.succeeded?
        $stderr.debugPuts(__FILE__, __method__, "Build Matrix Tool", "downloaded content of the #{gene}")
        line = @apiCaller.respBody
        content = line.split(/\n/)
        vectorLength = vectorLength + content.size
        content.each {|lineContent|
          column = lineContent.split(/\t/)
          avps = column[12].split(/Name=/)
          type = avps[1].split(/\;/)
          key = "#{column[4]}_#{column[5]}_#{column[6]}"
          @geneCorHash[key] = "#{column[1]}_#{type[0]}"
          }
      else
        $stderr.debugPuts(__FILE__, __method__, "Build Matrix Tool -Error", "#{@apiCaller.parseRespBody().inspect}")
        @exitCode = @apiCaller.apiStatusObj['statusCode']
      end
    }
    @noOfPoints = vectorLength
    $stderr.debugPuts(__FILE__, __method__, "Build Matrix Tool", "counts of the ROI track #{@noOfPoints}")
    @refLMHash     = GSL::Vector.alloc(@noOfPoints)
    @matixValHash  = Hash.new {|hash,key| hash[key] =GSL::Vector.alloc(@noOfPoints)}
    withROI()
    buildMatrix()
  end

  ##download the scores of each track using user defined gene list
  def withROI()
    firstTrack = true
    @trkNo = 0
    @trkSetHash.each_key{|trackSet|
      $stderr.debugPuts(__FILE__, __method__, "Downloading TRACK",trackSet)
      indexCounter = 0
      kk = @trackhelper.extractName(trackSet)
      newtrk = kk.gsub(/[:| ]/,'.')
      @geneHash.each_key {|gene|
        @apiCaller.get({:format => "bedgraph", :scrTrackPath =>trackSet,:name => gene, :esValue => 0})
        if @apiCaller.succeeded?
          $stderr.debugPuts(__FILE__, __method__, "Build Matrix Tool", "downloaded content of the #{gene}")
          skipHeader = false
          line = @apiCaller.respBody
          content = line.split(/\n/)
          content.each{|lineContent|
            if(skipHeader)
              column = lineContent.split(/\t/)
              key = "#{column[0]}_#{column[1].to_i+1}_#{column[2]}"
              @matixValHash[key][@trkNo] = column[3].to_f
            end
            skipHeader = true
          }
        else
          $stderr.debugPuts(__FILE__, __method__, "Build Matrix Tool -Error", "#{@apiCaller.parseRespBody().inspect}")
          @exitCode = @apiCaller.apiStatusObj['statusCode']
        end
      }
      @trkNo += 1
    }
  end

  ##building matrix
  def buildMatrix()
    saveFile = File.open("#{@scratch}/matrix/matrix.xls","w+")
    saveFileT = File.open("#{@scratch}/matrix/matrixTemp.xls","w+")
    saveFile.print "Index"
    @trkSetHash.each_key{|k|
      kk = @trackhelper.extractName(k)
      kk = kk.gsub(/[:| ]/,'.')
      saveFile.print "\t#{kk}"
    }
    saveFile.puts
    @geneCorHash.each_key {|line|
      line.strip!
      removeArray = []
      removeBuffer = ""
      for ii in 0 ... @trkNo
          if(@reomveNoData)
            removeArray.push(@matixValHash[line][ii])
          end
          removeBuffer << "\t#{@matixValHash[line][ii]}"
      end
        if(@reomveNoData == "true")
          if(removeArray.uniq.size != 1)
            saveFileT.print "#{@geneCorHash[line]}"
            saveFileT.print "#{removeBuffer}"
            saveFileT.puts
          end
        else
          saveFileT.print  "#{@geneCorHash[line]}"
          saveFileT.print "#{removeBuffer}"
          saveFileT.puts
        end

      }
    saveFileT.close
    saveFile.close
    system("sort -k1 #{@scratch}/matrix/matrixTemp.xls > #{@scratch}/matrix/matrixTemp1.xls ")
    system("cat #{@scratch}/matrix/matrixTemp1.xls >> #{@scratch}/matrix/matrix.xls")
    system("rm #{@scratch}/matrix/matrixTemp1.xls")

  end


  ##help section defined
  def GeneElementDataSlice.usage(msg='')
    unless(msg.empty?)
      puts "\n#{msg}\n"
    end
    puts "
      PROGRAM DESCRIPTION:
        epigenome data matrix builder
      COMMAND LINE ARGUMENTS:
        --trackSet     | -t => entitytrackSet(s) (comma separated)
        --geneList     | -r => gene List
        --apiDBRCKey   | -a => dBRC key
        --scratch      | -S => scratch area
        --removeNoData | -R => remove no data region (true|false)
        --help         | -h => [Optional flag]. Print help info and exit.
      usage:

        ";
      exit;
  end #

  # Process Arguements form the command line input
  def GeneElementDataSlice.processArguements()
    # We want to add all the prop_keys as potential command line options
    optsArray = [
                  ['--trackSet'        ,'-t', GetoptLong::REQUIRED_ARGUMENT],
                  ['--geneList'        ,'-r', GetoptLong::OPTIONAL_ARGUMENT],
                  ['--apiDBRCKey'      ,'-a', GetoptLong::OPTIONAL_ARGUMENT],
                  ['--scratch'         ,'-S', GetoptLong::REQUIRED_ARGUMENT],
                  ['--removeNoData'    ,'-R', GetoptLong::REQUIRED_ARGUMENT],
                  ['--userId'    ,'-u', GetoptLong::REQUIRED_ARGUMENT],
                  ['--help'            ,'-H', GetoptLong::NO_ARGUMENT]
                ]
    progOpts = GetoptLong.new(*optsArray)
    GeneElementDataSlice.usage("USAGE ERROR: some required arguments are missing") unless(progOpts.getMissingOptions().empty?)
    optsHash = progOpts.to_hash
    Coverage if(optsHash.empty? or optsHash.key?('--help'));
    return optsHash
  end

end

begin
optsHash = GeneElementDataSlice.processArguements()
performQCUsingFindPeaks = GeneElementDataSlice.new(optsHash)
performQCUsingFindPeaks.readGeneList()
performQCUsingFindPeaks.buildHashofVectorEntity()
rescue => err
      $stderr.puts "Details: #{err.message}"
      $stderr.puts err.backtrace.join("\n")
end
