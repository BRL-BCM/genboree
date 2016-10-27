#!/usr/bin/env ruby
require 'json'
require 'fileutils'
require 'cgi'
require 'brl/util/util'
require 'brl/util/emailer'
require 'gsl'
require 'brl/genboree/rest/apiCaller.rb'
require 'brl/genboree/rest/apiCaller'
require 'brl/genboree/helpers/expander'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'

include GSL
include BRL::Genboree::REST

class BuildMatrix

  #Initializes all the values
  def initialize(optsHash)
    @gbConfFile     = "/cluster.shared/local/conf/genboree/genboree.config.properties"
    @grph           = BRL::Genboree::REST::Helpers::GroupApiUriHelper.new(@gbConfFile)
    @dbhelper       = BRL::Genboree::REST::Helpers::DatabaseApiUriHelper.new(@gbConfFile)
    @trackhelper    = BRL::Genboree::REST::Helpers::TrackApiUriHelper.new(@gbConfFile)
    @trackSet1      = optsHash['--trackSet1']
    @trackSet2      = optsHash['--trackSet2']
    if(!optsHash.key?('--roiTrack'))
      @roi          = "na"
      @rDb          = "na"
      @rGrp         = "na"
      @usingROI     = false
    else
      @roitrk       = optsHash['--roiTrack'].chomp('?')
      @usingROI     = true
      @rDb 	    = @dbhelper.extractName(@roitrk)
      @rGrp 	    = @grph.extractName(@roitrk)
      @roi          = @trackhelper.extractName(@roitrk)
    end

    @span           = optsHash['--span']
    @scratch        = optsHash['--scratch']
    @resolution     = optsHash['--resolution']
    @filter         = optsHash['--filter']
    @normalized     = optsHash['--normalize']
    @apiDBRCkey     = optsHash['--apiDBRCKey']
    @output         = "."
    @userId         = optsHash['--userId']

    dbrc 	    = BRL::DB::DBRC.new(nil, @apiDBRCkey)
    @pass 	    = dbrc.password
    @user 	    = dbrc.user

    @tdb            = @dbhelper.extractName(@trackSet1)
    @tGrp           = @grph.extractName(@trackSet1)
    uri             = URI.parse(@trackSet1)
    @host           = uri.host
    @path1          = uri.path.chomp('?')
    uri             = URI.parse(@trackSet2)
    @path2          = uri.path.chomp('?')

    @matrixFH       = File.open("#{@scratch}/matrix/matrix.txt","w+")
    @trkSetHash1    = {}
    @trkSetHash2    = {}
  end


  ##Finding smaller trackSet so, download those all tracks in that trackset at once and
  ##keep comparing with other trackSet's track one by one. THIS ONE USES ENTITY LIST AS INPUT
  def buildHashEntity()
    exitStatus = 0
    fileHandle = File.open("#{@scratch}/tmpFile1.txt")
    fileHandle.each{|line|
      if(line != nil)
        line.strip!
        @trkSetHash1[line] = ""
      end
      }
    fileHandle.close
    fileHandle = File.open("#{@scratch}/tmpFile2.txt")
    fileHandle.each{|line|
      if(line!=nil)
        line.strip!

        @trkSetHash2[line] = ""
      end
      }
    fileHandle.close
    #File.delete("#{@scratch}/tmpFile1.txt")
    #File.delete("#{@scratch}/tmpFile2.txt")
    return exitStatus
  end



  ##downloading all the tracks of from the trackSet of smaller size first and then from the larger one by one bye one
  def runningTool()
    tempHash1 = {}
    tempHash2 = {}
    if(@trkSetHash1.size > @trkSetHash2.size)
      tempHash1 = @trkSetHash2
      tempHash2 = @trkSetHash1
    else
      tempHash1 = @trkSetHash1
      tempHash2 = @trkSetHash2
    end
    scriptFile = "downloadWig.rb"
    @matrixFH.write "X"
    tempHash1.each { |xTrk,value|
      xtrkName  = @trackhelper.extractName(xTrk)
      @matrixFH.write "\t#{xtrkName.gsub(/:/,"_")}"      
      cmd = "#{scriptFile} -s #{CGI.escape(xTrk)} -u #{@userId} -o #{@scratch}/signal-search/trksDownload -S #{CGI.escape(@span)}"
      if(@usingROI) then 
        cmd << " -r #{CGI.escape(@roitrk)} "
      else
        cmd << " -R #{CGI.escape(@resolution)} "
      end
      cmd << " >> #{@scratch}/logs/downloadX.log 2>>#{@scratch}/logs/downloadX.error.log"
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Download command for X = #{cmd.inspect}")
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Build Matrix Tool- Downloaded #{xtrkName.inspect}")
      system(cmd)
      if(!$?.success?)
        $stderr.debugPuts(__FILE__, __method__, "ERROR", "Build Matrix Tool- Download Error : #{xtrkName.inspect}")
        raise "Error downloading track #{xtrkName.inspect}"
      end
    }

    @matrixFH.puts
    tempHash2.each { |yTrk,value|
      ytrkName  = @trackhelper.extractName(yTrk)
      @matrixFH.write ytrkName.gsub(/:/,"_")
      cmd = "#{scriptFile} -s #{CGI.escape(yTrk)} -u #{@userId} -o #{@scratch}/signal-search/trksDownload -S #{CGI.escape(@span)}"
      if(@usingROI) then 
        cmd << " -r #{CGI.escape(@roitrk)} "
      else
        cmd << " -R #{CGI.escape(@resolution)} "
      end      
      cmd << " >> #{@scratch}/logs/downloadY.log 2>>#{@scratch}/logs/downloadY.error.log"
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Download command for Y : #{cmd.inspect}")
      ##Avoid downloading the same track again
      if(!File.exists?("#{@scratch}/signal-search/trksDownload/#{CGI.escape(CGI.escape(ytrkName))}"))
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Build Matrix Tool- Downloaded #{ytrkName.inspect}")
        system(cmd)
        if(!$?.success?)
           $stderr.debugPuts(__FILE__, __method__, "ERROR", "Build Matrix Tool- Download Error #{ytrkName.inspect}")
           raise "Error downloading track #{ytrkName.inspect}"
        end
      end
      if(@usingROI)
        @format = "Lff"
      else
        @format = "Wig"
      end
      tempHash1.each {|xTrk,value|
        xtrkName  = @trackhelper.extractName(xTrk)
        cmd1 = "signalSimilaritySearch.rb -f '#{CGI.escape(ytrkName)},#{CGI.escape(xtrkName)}' -s #{@scratch} -o #{@scratch}/matrix -F #{@format} -c #{@filter}"
        cmd1 << " -a trksDownload -r #{@resolution} -q #{@normalized} "
        cmd1 << " >> #{@scratch}/logs/signalSearch.log 2>>#{@scratch}/logs/signalSearch.error.log"
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "SignalComparison between #{xTrk.inspect} and #{yTrk.inspect}" )
        $stderr.debugPuts(__FILE__, __method__, "STATUS", " signalSimilaritySearch cmd: #{cmd1.inspect}")
        system(cmd1)
        if(!$?.success?)
          $stderr.debugPuts(__FILE__, __method__, "ERROR", "Build Matrix Tool- SignalSearch Call failed for #{yTrk.inspect} and #{xTrk.inspect}")
        end
        fileRead = File.open("#{@scratch}/signal-search/trksDownload/summary.txt")
        fileRead.each_line {|line|
          line.strip!
          c = line.split(/\t/)
          @matrixFH.write "\t#{c[1]}"
        }
        File.delete("#{@scratch}/signal-search/trksDownload/summary.txt")
      }
      @matrixFH.puts
      ##Dont delete track if its on both the trackSets
      if(!tempHash1.key?(yTrk))
        #File.delete("#{@scratch}/signal-search/trksDownload/#{CGI.escape(CGI.escape(yTrk))}")
      end
    }
    @matrixFH.close
    system("ls #{@scratch}/signal-search/trksDownload/*|grep -v log|xargs rm -rf")
  end


  ##help section defined
  def BuildMatrix.usage(msg='')
    unless(msg.empty?)
      puts "\n#{msg}\n"
    end
    puts "
      PROGRAM DESCRIPTION:
        epigenome attribute values retiever
      COMMAND LINE ARGUMENTS:
        --trackSet1         | -t => trackSet1
        --trackSet2         | -T => trackSet2
        --roiTrack          | -r => (OPTIONAL)roiTrack
        --apiDBRCKey        | -a => apiDBRCKey
        --span              | -s => span
        --scratch           | -S => scratch
        --resolution        | -R => resolution
        --filter            | -f => filtering (true|false)
        --normalize         | -n => normalized (true|false)
        --userId            | -u => userId
        --help              | -h => [Optional flag]. Print help info and exit.

      usage:
      ruby epigenomeHeatMapTool.rb -t {trackset1} -T {trackSet2}  -r {roiTrack} -a valineApi -S /scratch/testing -R 10000 -f false -n false-s AVG

        ";
      exit;
  end #

  # Process Arguements form the command line input
  def BuildMatrix.processArguements()
    # We want to add all the prop_keys as potential command line options
    optsArray = [
                  ['--trackSet1'       ,'-t', GetoptLong::REQUIRED_ARGUMENT],
                  ['--trackSet2'       ,'-T', GetoptLong::REQUIRED_ARGUMENT],
                  ['--roiTrack'        ,'-r', GetoptLong::OPTIONAL_ARGUMENT],
                  ['--apiDBRCKey'      ,'-a', GetoptLong::OPTIONAL_ARGUMENT],
                  ['--span'            ,'-s', GetoptLong::REQUIRED_ARGUMENT],
                  ['--scratch'         ,'-S', GetoptLong::REQUIRED_ARGUMENT],
                  ['--resolution'      ,'-R', GetoptLong::REQUIRED_ARGUMENT],
                  ['--filter'          ,'-f', GetoptLong::REQUIRED_ARGUMENT],
                  ['--normalize'       ,'-n', GetoptLong::REQUIRED_ARGUMENT],
                  ['--userId'       ,'-u', GetoptLong::REQUIRED_ARGUMENT],
                  ['--help'            ,'-h', GetoptLong::NO_ARGUMENT]
                ]
    progOpts = GetoptLong.new(*optsArray)
    BuildMatrix.usage("USAGE ERROR: some required arguments are missing") unless(progOpts.getMissingOptions().empty?)
    optsHash = progOpts.to_hash
    Coverage if(optsHash.empty? or optsHash.key?('--help'));
    return optsHash
  end

end

begin
optsHash = BuildMatrix.processArguements()
createMatrix = BuildMatrix.new(optsHash)
createMatrix.buildHashEntity()
createMatrix.runningTool()

rescue => err
      $stderr.debugPuts(__FILE__, __method__, "ERROR", "#{err.message}")
      $stderr.debugPuts(__FILE__, __method__, "ERROR", "#{err.backtrace.join("\n")}")
      exit(113)
end
