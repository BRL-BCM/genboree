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

class EpigenomicAttributeWrapper

  def initialize(optsHash)
    @trackSet1 = optsHash['--trackSet1']
    @trackSet2 = optsHash['--trackSet2']
    @roitrk    = optsHash['--roiTrack']
    @span      = optsHash['--span']
    @output    = CGI.escape(optsHash['--output'])
    @scratch   = File.expand_path(optsHash['--scratch'])
    @apiDBRCkey= optsHash['--apiDBRCKey']
    @userId = optsHash['--userId']
    @trkNumber = 0
    @attributearray = []

    @gbConfFile     = "/cluster.shared/local/conf/genboree/genboree.config.properties"
    @grph           = BRL::Genboree::REST::Helpers::GroupApiUriHelper.new(@gbConfFile)
    @dbhelper       = BRL::Genboree::REST::Helpers::DatabaseApiUriHelper.new(@gbConfFile)
    @trackhelper    = BRL::Genboree::REST::Helpers::TrackApiUriHelper.new(@gbConfFile)

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
    uri             = URI.parse(@roitrk)
    @rPath          = uri.path.chomp('?')

    system("mkdir -p #{@scratch}/matrix")
    @trkSetHash1 = {}
    #@matixValHash  = Hash.new {|hash,key| hash[key] =GSL::Vector.alloc(10)}
  end


  ##initializing gsl vector and making hash of vectors. This one uses ENTITY LIST as input
  def buildHashofVectorEntity()
    fileHandle = File.open("#{@scratch}/tmpFile1.txt")
    fileHandle.each{|line|
      line.strip!
      @trkSetHash1[line] = "SetA"
      }
    fileHandle.close
    fileHandle = File.open("#{@scratch}/tmpFile2.txt")
    fileHandle.each{|line|
      line.strip!
      @trkSetHash1[line] = "SetB"
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
      #@exitCode = apicaller.apiStatusObj['statusCode']
      raise "Build Matrix Tool -Error"
    end
    temp = apicaller.parseRespBody
    @noOfPoints = temp["data"]["count"].to_i
    $stderr.debugPuts(__FILE__, __method__, "Build Matrix Tool", "counts of the ROI track #{@noOfPoints}")
    @refLMHash     = GSL::Vector.alloc(@noOfPoints)
    @matixValHash  = Hash.new {|hash,key| hash[key] =GSL::Vector.alloc(@noOfPoints)}
  end


  ##main function to call other ones
  def findingAttribute()
    @trkSetHash1.each_key{|k|
        withROI(k)
        @trkNumber += 1
        t =+ 1
    }
   buildMatrix()
   buildMetadata()
  end

  ##building metadata file
  def buildMetadata()
    fileWrite = File.open("#{@scratch}/matrix/metadata.txt", "w+")
    fileWrite.write "#name\tclass"
    fileWrite.puts
    @trkSetHash1.each{|k,v|
      unless(k == nil)
        kk = @trackhelper.extractName(k)
        kk = kk.gsub(/[:| ]/,'.')
        fileWrite.write "#{kk}\t#{v}\n"
       end
      }
    fileWrite.close

  end

  ##download the tracks
  def withROI(trk)
    newtrk  = trk.gsub(/[:| ]/,'.')
    if(@trkNumber == 0 )
      tempFile = File.open("#{@scratch}/matrix/tempLM.txt","w+")
    end
    indexCounter = 0
    trkName = @trackhelper.extractName(trk)
    newtrk  = trkName.gsub(/[:| ]/,'.')
    apicaller = WrapperApiCaller.new(@trackhelper.extractHost(@roitrk),"",@userId)
    path = "#{@trackhelper.extractPath(@roitrk)}/annos?format=lff&scoreTrack={scrTrack}&spanAggFunction={span}&emptyScoreValue={esValue}"
    path << "&gbKey=#{@trackhelper.extractGbKey(@roitrk)}" if(@trackhelper.extractGbKey(@roitrk))
    apicaller.setRsrcPath(path)
    @buff = ''
    params = {
                                :scrTrack => trk,
                                :esValue  => "NaN",
                                :format   => "lff",
                                :span     => @span
                              }
    
    ## downloading lff/bedgraph file
    httpResp = apicaller.get(params){|chunck|
                    fullChunk = "#{@buff}#{chunck}"
                    @buff = ''
                    fullChunk.each_line { |line|
                      if(line[-1].ord == 10)
                        column = line.split(/\t/)
                        if(@trkNumber == 0 )
                          tempFile.puts "#{column[4]}_#{column[5]}_#{column[6]}_#{indexCounter}"
                        end
                          #@refLMHash[indexCounter] = "#{chrNo}000#{column[5]}000#{column[6]}".to_f
                        @matixValHash[newtrk][indexCounter] = column[9].to_f
            
                        indexCounter += 1
                      else
                        @buff += line
                      end
                      }
            }
            if apicaller.succeeded?
               $stderr.debugPuts(__FILE__, __method__, "Build Matrix Tool", "Successfully downloaded #{trkName}")
            else
              $stderr.debugPuts(__FILE__, __method__, "Build Matrix Tool -Error", "Download Failure #{trkName}")
              $stderr.debugPuts(__FILE__, __method__, "Build Matrix Tool -Error ", "#{apicaller.parseRespBody().inspect}")
              @exitCode = apicaller.apiStatusObj['statusCode']
              raise "Error downloading tracks to create matrix"
            end
      if(@trkNumber == 0 )
          tempFile.close
      end
  end

  ##building matrix
  def buildMatrix()
    saveFile = File.open("#{@scratch}/matrix/matrix.txt","w+")
    saveFile.print "Index"
    @trkSetHash1.each_key{|k|
      kk = @trackhelper.extractName(k)
      kk = kk.gsub(/[:| ]/,'.')
      saveFile.print "\t#{kk}"
    }
    saveFile.puts
    lmHandler = File.open("#{@scratch}/matrix/tempLM.txt")
    counter = 0
    lmHandler.each {|line|
      line.strip!
      removeArray = []
      removeBuffer = ""
        @trkSetHash1.each_key{|k|
          kk = @trackhelper.extractName(k)
          kk = kk.gsub(/[:| ]/,'.')
          if(@reomveNoData)
            removeArray.push(@matixValHash[kk][counter])
          end
          removeBuffer << "\t#{@matixValHash[kk][counter]}"
        }
        if(@reomveNoData)
          unless(removeArray.uniq.size != removeArray.size)
            saveFile.print line
            saveFile.print "#{removeBuffer}"
            saveFile.puts
          end
        else
          saveFile.print line
          saveFile.print "#{removeBuffer}"
          saveFile.puts
        end
        counter += 1
    }
    saveFile.close
  end


  ##help section defined
  def EpigenomicAttributeWrapper.usage(msg='')
    unless(msg.empty?)
      puts "\n#{msg}\n"
    end
    puts "
      PROGRAM DESCRIPTION:
        epigenome attribute values retiever
      COMMAND LINE ARGUMENTS:
        --trackSet1    | -t => Input trackSet1
        --trackSet2    | -T => Input trackSet2
        --roiTrack     | -r => roi track
        --apiDBRCKey   | -a => dBRC key
        --span         | -s => span size
        --scratch      | -S => scratch area
        --help         | -h => [Optional flag]. Print help info and exit.
      usage:

        ";
      exit;
  end #

  # Process Arguements form the command line input
  def EpigenomicAttributeWrapper.processArguements()
    # We want to add all the prop_keys as potential command line options
    optsArray = [
                  ['--trackSet1'       ,'-t', GetoptLong::REQUIRED_ARGUMENT],
                  ['--trackSet2'       ,'-T', GetoptLong::REQUIRED_ARGUMENT],
                  ['--roiTrack'        ,'-r', GetoptLong::OPTIONAL_ARGUMENT],
                  ['--apiDBRCKey'      ,'-a', GetoptLong::OPTIONAL_ARGUMENT],
                  ['--span'            ,'-s', GetoptLong::REQUIRED_ARGUMENT],
                  ['--scratch'         ,'-S', GetoptLong::REQUIRED_ARGUMENT],
                  ['--userId'         ,'-u', GetoptLong::REQUIRED_ARGUMENT],
                  ['--help'            ,'-H', GetoptLong::NO_ARGUMENT]
                ]
    progOpts = GetoptLong.new(*optsArray)
    EpigenomicAttributeWrapper.usage("USAGE ERROR: some required arguments are missing") unless(progOpts.getMissingOptions().empty?)
    optsHash = progOpts.to_hash
    Coverage if(optsHash.empty? or optsHash.key?('--help'));
    return optsHash
  end

end

begin
optsHash = EpigenomicAttributeWrapper.processArguements()
performQCUsingFindPeaks = EpigenomicAttributeWrapper.new(optsHash)
performQCUsingFindPeaks.buildHashofVectorEntity()
performQCUsingFindPeaks.findingAttribute()
rescue => err
      $stderr.puts "Details: #{err.message}"
      $stderr.puts err.backtrace.join("\n")
      exitCode = 113
      exit(exitCode)
end
