#!/usr/bin/env ruby
require 'brl/genboree/tools/toolWrapper'
require 'brl/genboree/rest/wrapperApiCaller'
require 'brl/genboree/tools/scripts/randomForest/randomForestDriver'
require 'stringio'
require 'brl/genboree/rest/helpers/trackEntityListApiUriHelper'


module BRL; module Genboree; module Tools; module Scripts

  class MatrixCreator
    def checkForValidInputs
      # Is the comparison based on chosen track attribute values?
      entityListCount = 0
      @trkUriLists = []
      trkUris = []
      @numTracks = 0
      @jc["inputs"].each { |input|
        # Ensure we're matching against the *path* part of a URI, not some uri that's in a parameter or something
        uri = URI.parse(input) rescue false
        if(uri)
          if(@jc["noAttributes"] and uri.path !~ %r{/trks/entityList/}) then # Error, inputs must be track entity lists when no attributes are provided
            @errUserMsg = "Invalid Inputs. When no track attributes are specified, inputs must be track entity lists.\n#{input} is not a valid input"
            @exitCode = 30
            return @exitCode
          elsif(uri.path =~ %r{/trks/entityList/})
            entityListCount += 1
            @trkUriLists[entityListCount - 1] = []
            # Have track list, collect get all tracks within
            trks = downloadTrackEntityList(input)
            if(trks)
              trks.each { |trkUri|
                @trkUriLists[entityListCount - 1] << trkUri
                @numTracks += 1
              }
            end
          elsif(uri.path =~ %r{/trk/})              # Have just a track, collect just it
            trkUris << input
            @numTracks += 1
          end
        end
      }
      if(@jc["noAttributes"] and entityListCount <= 1) then
        @errUserMsg = "Insufficient Inputs. When no track attributes are specified, atleast two track entity lists must be provided."
        @exitCode = 30
        return @exitCode
      end
      @trkUriLists << trkUris
    end
    
    def validateSettings
      checkForValidInputs()
      generateAttrNamesAndValues()
    end
    
    def createMatrix
      downloadTracks()
      createTrackMatrix()
    end
    
    def initialize(jobConf)
      @jc = jobConf
      @valueCounts = Hash.new{|h,k| h[k]=Hash.new(0)}
      @attrValues = Hash.new{|h,k| h[k]=Hash.new}
      @trkListApiHelper = BRL::Genboree::REST::Helpers::TrackEntityListApiUriHelper.new
      @trkApiHelper = BRL::Genboree::REST::Helpers::TrackApiUriHelper.new
      if(@jc["qiimeFormat"]) then @qiimeFormat = true
      else
        @qiimeFormat = false
      end
    end
    
    def getNumTracks
      return @numTracks
    end
    
    def getValueCounts
      return @valueCounts
    end
    
    def getAttrValues
      return @attrValues
    end
    
    def getTrkUriLists
      return @trkUriLists
    end
    
   def generateAttrNamesAndValues
      apiCaller = WrapperApiCaller.new("", "", @jc["userId"])
      @jc["attrNames"].each{|attrName|
        @trkUriLists.each_index{|tt|
          attrValue = "Set_#{tt}"
          @trkUriLists[tt].each{|track|
            if(!@jc["noAttributes"]) then
              apiCaller.setHost(@trkApiHelper.extractHost(track))
              apiCaller.setRsrcPath("#{@trkApiHelper.extractPath(track)}/attribute/#{attrName}/value?#{URI.parse(track).query}")
              apiCaller.get
              if(apiCaller.succeeded?) then
                apiCaller.parseRespBody
                attrValue = apiCaller.apiDataObj["text"]
              else
                $stderr.debugPuts(__FILE__, __method__, "ERROR", "Unable to retrieve value of attribute #{attrName} for track #{track}:\n\n#{apiCaller.respBody}\n\n")
                attrValue = :error
              end
            end #get value for track
            @attrValues[attrName][CGI.escape(@trkApiHelper.extractName(track))] = attrValue
            @valueCounts[attrName][attrValue] += 1
          }
        }
      }
    end
    
    def downloadTracks
      scriptFile = "downloadWig.rb"
      system("mkdir -p #{@jc["scratch"]}/trksDownload")
      @trkUriLists.each{|tl|
        tl.each{|track|
          downloadCmd = "#{scriptFile} -b -e #{CGI.escape(@jc["esValue"])} -s #{CGI.escape(track)} -u #{@jc["userId"]} -o #{@jc["scratch"]}/trksDownload -S #{CGI.escape(@jc["span"])}"
          $stderr.debugPuts(__FILE__,__method__,"DEBUG","Downloading track #{track}")
          if(@jc["usingROI"]) then
            downloadCmd << " -r #{CGI.escape(@jc["roiTrack"])}"
            $stderr.debugPuts(__FILE__,__method__,"DEBUG","Using roi track #{@jc["roiTrack"]}")
          else
            downloadCmd << " -R #{CGI.escape(@jc["resolution"])}"
            $stderr.debugPuts(__FILE__,__method__,"DEBUG","Using resolution #{@jc["resolution"]}")
          end
          $stderr.debugPuts(__FILE__,__method__,"DEBUG","Download Command is: #{downloadCmd}")
          system(downloadCmd)
          if(!$?.success?)
            $stderr.debugPuts(__FILE__, __method__, "ERROR", "Unable to download track #{track}")
            raise "Error downloading track #{track}"
          end
        }
      }
      if(@jc["usingROI"]) then
        downloadROITrack()
      end

    end

    def downloadROITrack
      begin
        @roiTrack = @jc["roiTrack"]
        roiHost = @trkApiHelper.extractHost(@roiTrack)
        apiCaller = WrapperApiCaller.new(roiHost, "", @jc["userId"])
        # Turn on when correct header available
        rsrcPath = "#{@trkApiHelper.extractPath(@roiTrack)}/annos?#{URI.parse(@roiTrack).query}&format={format}&addCRC32Line=true&ucscTrackHeader=true"
        apiCaller.setRsrcPath(rsrcPath)
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "FILLED apiCaller rsrcPath: " +rsrcPath)
        system("mkdir -p #{@jc["scratch"]}/trksDownload")
        @roiFile = "#{@jc["scratch"]}/trksDownload/#{CGI.escape(@trkApiHelper.extractName(@roiTrack))}"
        saveFile = File.open(@roiFile,"w+")
        httpResp = apiCaller.get(
        {
          :format   => "bed"
        }){ |chunk|
          saveFile.write chunk
        }
        saveFile.close
        if(apiCaller and apiCaller.succeeded?)
          $stdout.puts "Successfully downloaded file"
          # Checksum will not work with dummy header
          if(!File.verifyCheckSum(@roiFile)) then
            errMsg = "Retrieved and Computed checksums for #{@roiFile} do not match"
            $stderr.debugPuts(__FILE__, __method__, "ERROR", errMsg)
            @exitCode = 152
            @errMsg = errMsg
            raise errMsg
          end
        else
          errMsg = "ApiCaller failed.host:#{roiHost}; httpResp: #{apiCaller.httpResponse.inspect}; hostAuthMap: #{apiCaller.hostAuthMap.inspect}; rsrcPath:\n  #{apiCaller.rsrcPath.inspect}"
          $stderr.debugPuts(__FILE__, __method__, "ERROR", errMsg)
          @exitCode = 152
          @errMsg = errMsg
          raise errMsg
        end
      rescue => err
        $stderr.puts "ERROR raised: #{err.message}\n#{err.backtrace.join("\n")}"
      end
    end

    def createTrackMatrix
      fileHandles = {}
      @trkUriLists.each{|tl|
        tl.each{|track|
          trackName = CGI.escape(@trkApiHelper.extractName(track))
          fileHandles[trackName] = File.open("#{@jc["scratch"]}/trksDownload/#{trackName}","r")
        }
      }
      otufh = File.open("#{@jc["scratch"]}/#{@jc["matrixFileName"]}","w")
      @trkUriLists.each{|tl|
        tl.each{|track|
          trackName = CGI.escape(@trkApiHelper.extractName(track))
          fileHandles[trackName] = File.open("#{@jc["scratch"]}/trksDownload/#{trackName}","r")
        }
      }
      otufh.puts "#Dummy Line"
      otufh.print "#OTU ID"
      fileHandles.each_key{|track|
        otufh.print "\t#{track}"
        fileHandles[track].readline() # Chew up header line in each file
      }
      if(!@qiimeFormat) then otufh.print("\tAnnotation") end
      otufh.puts
      roifh = nil
      if(@jc["usingROI"]) then
        roifh = File.open(@roiFile,"r")
        roifh.readline()
      end
      eofReached = false
      lineString = StringIO.new
      validLineCount = 0
      while(!eofReached)
        validLine = true
        lineString.truncate(lineString.rewind)
        landMark = nil
        roiString = nil
        fileHandles.each_key{|track|
          if(fileHandles[track].eof?) then
            validLine =false
            eofReached = true
          else
            sl = fileHandles[track].readline().chomp.split(/\t/)
            if(sl[3] == @jc["esValue"]) then
              validLine = false
            else
              lineString << "\t#{sl[3]}"
              if(landMark.nil?) then
                coords = "#{sl[0]}:#{sl[1].to_i+1}-#{sl[2]}"
                if(@jc["usingROI"]) then
                  ssl = roifh.readline().chomp.split(/\t/)
                  roiString = ssl[3]
                  landMark = "#{roiString};#{coords}"
                else
                  landMark = coords # Compute once per lineString
                end
              end
            end
          end
        }
        if(validLine)
          otufh.print "#{validLineCount}#{lineString.string}"
          if(!@qiimeFormat) then otufh.print "\t#{landMark}" end
          otufh.puts
          validLineCount += 1
        end
      end
      fileHandles.each_key{|track| fileHandles[track].close}
      if(@jc["usingROI"]) then roifh.close end
      otufh.close
    end
      
    def downloadTrackEntityList(rsrcUri)
      retVal = nil
      begin
        if(listName = @trkListApiHelper.extractName(rsrcUri))
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Downloading track entity list #{listName.inspect}")
          host = @trkListApiHelper.extractHost(rsrcUri)
          trkListPath = @trkListApiHelper.extractPath(rsrcUri, true) # true means include gbKey if present
          apiCaller = WrapperApiCaller.new(host, trkListPath, @jc["userId"])
          httpResp = apiCaller.get()
          if(apiCaller.succeeded?)
            retVal = []
            apiCaller.parseRespBody()
            apiCaller.apiDataObj.each { |urlEntity|
              retVal << urlEntity['url']
            }
          else # API FAILED
            raise "ERROR: API download of track entity list #{rsrcUri.inspect} failed. Returned #{httpResp.inspect}. Response payload:\n\n#{apiCaller.respBody}\n\n"
          end
        end
      rescue => err
        @err = err
        @errInternalMsg = err.message
        @errUserMsg = "ERROR: failure during download of track entity list contents."
        raise err
      end
      return retVal
    end


  end


end
end
end
end
