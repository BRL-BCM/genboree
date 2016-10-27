#!/usr/bin/env ruby

require 'cgi'
require 'json'
require 'pathname'
require 'gsl'
require 'brl/util/util'
require 'brl/genboree/rest/wrapperApiCaller'
require 'brl/util/expander'
require 'brl/stats/stats'
require 'brl/stats/R/rUtils'
require 'brl/genboree/tools/toolWrapper'
require 'brl/genboree/tools/wrapperEmailer'
require 'brl/genboree/helpers/parallelTrackDownload'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/geneViewer/gbTrackUtilNew'
require 'brl/genboree/graphics/graphlanViewer'
require 'brl/genboree/graphics/d3/d3horizontalDendogram'

include BRL::Genboree::REST

# Write sub-class of BRL::Genboree::Tools::ToolWrapper
module BRL ; module Genboree; module Tools
  class WrapperEpigenomeHeatmap < ToolWrapper

    VERSION = "1.5"

    DESC_AND_EXAMPLES = {
      :description => "Wrapper to run tool, which generates heatmap on sets of epigenomic experiment",
      :authors      => [ "Sriram Raghuram, Sameer Paithankar, Andrew R Jackson" ],
      :examples => [
        "#{File.basename(__FILE__)} --jsonFile=filePath",
        "#{File.basename(__FILE__)} -j filePath",
        "#{File.basename(__FILE__)} --help"
      ]
    }

    #  .  Program will exit with that code. 0 means success.
    #  . Command-line args will already be parsed and checked for missing required values
    #  . optsHash contains the command-line args, keyed by --longName
    def run()
      trun = Time.now
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Running Driver .....")
      exitStatus = EXIT_OK
      @errUsrMsg = ""
      # Create R engine to [re]use for phyper() calculations
      # - we don't need a new, independent engine; the shared global R is fine (so create with "false")
      @rUtil = BRL::Stats::R::RUtils.new(false)
      begin
        apiUriHelper = BRL::Genboree::REST::Helpers::ApiUriHelper.new()
        @tracksSummaryHash = {}
        entityLists = []
        roiTrack = nil
        inputsOK = true
        shorterListIndex = nil
        shorterListSize = nil
        inputIdx = 0
        shorterListTrks = []
        longerListIndex = nil
        longerListTrks = []
        @entityNameWithMoreTrks = nil
        @entityNameWithLessTrks = nil
        @inputs.each { |input|
          inpType = apiUriHelper.extractType(input)
          # For entity lists make sure all tracks still exist as-is
          if(inpType == "entityList")
            entityListName = @trkListApiHelper.extractName(input)
            entityLists << input
            uriObj = URI.parse(input)
            apiCaller = WrapperApiCaller.new(uriObj.host, uriObj.path, @userId)
            apiCaller.get()
            if(!apiCaller.succeeded?)
              exitStatus = 110
              @errUsrMsg = apiCaller.respBody
              inputsOK = false
              break
            else
              resp = apiCaller.parseRespBody['data']
              if(@entityNameWithMoreTrks)
                if(@tracksSummaryHash[@tracksSummaryHash.keys[0]][:total].size <= resp.size)
                  @entityNameWithMoreTrks = entityListName
                  @entityNameWithLessTrks = @tracksSummaryHash.keys[0]
                else
                  @entityNameWithLessTrks = entityListName
                end
              else
                @entityNameWithMoreTrks = entityListName
                @entityNameWithLessTrks = entityListName
              end
              @tracksSummaryHash[@trkListApiHelper.extractName(input)] = { :total => resp, :missing => {} }
              resp.each { |ii|
                trkUrl = ii['url']
                trkUrlObj = URI.parse(trkUrl)
                apiCaller = WrapperApiCaller.new(trkUrlObj.host, trkUrlObj.path, @userId)
                apiCaller.get()
                if(!apiCaller.succeeded?)
                  $stderr.debugPuts(__FILE__,__method__,"trkUrl",trkUrl.inspect)
                  inputsOK = false
                  exitStatus = 120
                  @tracksSummaryHash[entityListName][:missing][trkUrl] = nil
                else
                  # Also check if the track has any data. Remove from list if it doesn't
                  apiCaller = WrapperApiCaller.new(trkUrlObj.host, "#{trkUrlObj.path}/annos/count?", @userId)
                  apiCaller.get()
                  if(!apiCaller.succeeded? or apiCaller.parseRespBody['data']['count'] < 1)
                    @tracksSummaryHash[entityListName][:missing][trkUrl] = nil
                  end
                end
              }
              ####################################################
              ### The variables below are no longer in use #######
              ####################################################
              #if(shorterListIndex.nil?)
              #  shorterListIndex = inputIdx
              #  shorterListSize = resp.size
              #  shorterListTrks = resp
              #  longerListIndex = inputIdx
              #  longerListTrks = resp
              #else
              #  if(resp.size <= shorterListSize)
              #    shorterListIndex = inputIdx
              #    shorterListTrks = resp
              #  else
              #    longerListIndex = inputIdx
              #    longerListTrks = resp
              #  end
              #end
            end
          elsif(inpType == "trk")
            roiTrack = input
            # The ROI track must exist and must be non empty
            urlObj = URI.parse(input)
            apiCaller = WrapperApiCaller.new(urlObj.host, "#{urlObj.path}/annos/count?", @userId)
            apiCaller.get()
            if(!apiCaller.succeeded? or apiCaller.parseRespBody['data']['count'] < 1)
              raise "ROI Track is either missing or has no annotations."
            end
          end
          inputIdx += 1
        }
        # Make sure there are at least 2 valid tracks in each list before processing
        @tracksSummaryHash.each_key { |list|
          if((@tracksSummaryHash[list][:total].size - @tracksSummaryHash[list][:missing].keys.size) < 2)
            raise "There must be at least 2 tracks in each track entity list that are accessible (not been deleted/moved/renamed) and have data to generate the heatmap."
          end
        }
        @yAxisTrks = []
        @tracksSummaryHash[@entityNameWithMoreTrks][:total].each { |trkUrl|
          @yAxisTrks << trkUrl['url'] if(!@tracksSummaryHash[@entityNameWithMoreTrks][:missing].has_key?(trkUrl['url']))
        }
        #longerListTrks.each { |trkUrl|
        #  @yAxisTrks << trkUrl['url']
        #}
        # If all inputs are genuine, proceed
        if(inputsOK)
          #downloadShorterList(shorterListTrks, roiTrack)
          downloadShorterList(roiTrack)
          $stderr.debugPuts(__FILE__, __method__, "List X: #{(@xAxisTrks.keys.size)} tracks", "\n#{@xAxisTrks.keys.join("\n")}.")
          $stderr.debugPuts(__FILE__, __method__, "List Y: #{(@yAxisTrks.size)} tracks", "\n#{@yAxisTrks.join("\n")}.")
          prepareMatrix(roiTrack)
          runHeatMapTool()
          tt = Time.now
          computeSVD()
          $stderr.debugPuts(__FILE__, __method__, "TIME", "Time to compute svd: #{Time.now - tt} seconds.")
          renameMap = {"newick.txt.scaled" => "Scaled",
            "newick.txt.nlog" => "logn",
            "newick.txt.log10" => "log10",
            "newick.txt.eq" => "eq"
            }
          exts = ["png","svg.html"]
          renameMap.each { |kk,vv|
            exts.each { |ee|
              File.rename("rows.#{kk}.#{ee}","rows#{vv}.#{ee}")
              File.rename("columns.#{kk}.#{ee}","columns#{vv}.#{ee}")
            }
          }
          runImportTool()
        end
        @exitCode = exitStatus
        if(exitStatus == EXIT_OK)
          uploadData()

          $stderr.debugPuts(__FILE__, __method__, "ES", $?.exitstatus.inspect)
          if($?.exitstatus == 118)
            exitStatus = 118
            @errUsrMsg = "Upload failed"
          elsif($?.exitstatus != EXIT_OK)
            exitStatus = 119
            @errUsrMsg = "Upload encountered an unexpected error"
          end
        end
        @exitCode = exitStatus
        #end
        $stderr.debugPuts(__FILE__, __method__, "Status", "Wrapper run() completed with #{exitStatus}. Time: #{Time.now - trun}")
      rescue Exception => err
        exitStatus = 30
        @errUsrMsg = err.message
        $stderr.puts err.message
        $stderr.puts err.backtrace.join("\n")
      ensure
        # Cleanup
        `rm -f *scores *common`
      end
      # Shutdown our R engine as cleanly as we can.
      @rUtil.shutdown() rescue false
      return exitStatus
    end

    # To import heatmap to atlas area
    def runImportTool()
      $stderr.debugPuts(__FILE__, __method__, "Running", "Import Tool")
      cmd ="importHeatmap.rb "
      cmd <<" -i #{@scratch} -j #{@scratch}/jobFile.json"
      cmd << " > #{@scratch}/logs/importTool.out 2>#{@scratch}/logs/importTool.err "
      $stderr.debugPuts(__FILE__, __method__, "Imort Tool command ", cmd)
      exitStatus = EXIT_OK
      system(cmd)
      if($?.exitstatus == 113)
        raise "Could not import heatmap to project area."
      else
        $stderr.debugPuts(__FILE__, __method__, "Done", "Import Tool")
      end
      $stderr.debugPuts(__FILE__, __method__, "Status", "Import tool completed with #{exitStatus}")
    end

    def prepareMatrix(roiTrack)
      `mkdir -p matrix`
      matrixHash = {}
      timeHash = { 'download track' => 0, 'extract' => 0, 'cut' => 0, 'normalize' => 0, 'corr' => 0, 'compare setup' => 0, 'create common files' => 0 }
      xBuffer = ""
      yBuffer = ""
      indexSorter = nil
      bufferSize = 32 * 1024 * 1024
      longerListTrks = @tracksSummaryHash[@entityNameWithMoreTrks][:total]
      #@tracksSummaryHash[@entityNameWithMoreTrks][:total].each {|trk|
      
      longerListTrks.each { |trk|
        next if(@tracksSummaryHash[@entityNameWithMoreTrks][:missing].has_key?(trk['url']))
        trkUrl = trk['url']
        fileName = SHA1.hexdigest(trkUrl)
        yAxisTrk = @trkApiHelper.extractName(trkUrl)
        if(!@xAxisTrks.has_key?(trkUrl))
          regions = roiTrack ? roiTrack : @resolution
          t1=Time.now
          retVal = @trkApiHelper.getDataFileForTrack(trkUrl, 'bedGraph', @span, regions, fileName, @userId, nil, 'n/a', 10)
          timeHash['download track'] += ( Time.now - t1 )
          unless(retVal)
            raise "Error: Could not download trk: #{trkUrl}"
          end
          exp = BRL::Util::Expander.new(fileName)
          t1=Time.now
          exp.extract()
          timeHash['extract'] += ( Time.now - t1 )
          t1=Time.now
          `cut -f4 #{exp.uncompressedFileName} > #{fileName}.scores`
          timeHash['cut'] += ( Time.now - t1 )
          File.delete(exp.uncompressedFileName)
          `rm -f #{exp.uncompressedFileName}`
        end
        yFile = "#{fileName}.scores"
        # Create x' and y' files with common regions
        @xAxisTrks.each_key { |xAxisTrkUrl|
          if(xAxisTrkUrl == trkUrl)
            matrixHash["#{trkUrl}_#{xAxisTrkUrl}"] = 1.0
            matrixHash["#{xAxisTrkUrl}_#{trkUrl}"] = 1.0
            next
          end
          if(matrixHash.has_key?("#{trkUrl}_#{xAxisTrkUrl}") or matrixHash.has_key?("#{xAxisTrkUrl}_#{trkUrl}"))
            next
          end
          #t1 = Time.now
          xFile = @xAxisTrks[xAxisTrkUrl]
          xAxisTrk = @trkApiHelper.extractName(xAxisTrkUrl)
          # The number of lines MUST be equal to compare
          xLines = `wc -l #{xFile}`.to_i
          yLines = `wc -l #{yFile}`.to_i
          raise "Error: Number of lines in downloaded file for tracks: #{xAxisTrk} and #{yAxisTrk} not equal. (Internal Error: Please contact the Genboree development team.)" if(xLines != yLines)
          xReader = File.open(xFile)
          yReader = File.open(yFile)
          xcommonFile = "x.common"
          ycommonFile = "y.common"
          xPrimeWriter = File.open(xcommonFile, 'w')
          yPrimeWriter = File.open(ycommonFile, 'w')
          # Skip the track headers
          xReader.readline
          yReader.readline
          commonRegions = 0
          #timeHash['compare setup'] += (Time.now - t1)
          #t1 = Time.now
          (xLines - 1).times { |ii|
            xScore = xReader.readline.chomp
            yScore = yReader.readline.chomp
            xNA = (xScore == "n/a")
            yNA = (yScore == "n/a")
            if (xNA) then xScore = @replaceNAValue end
            if (yNA) then yScore = @replaceNAValue end
            printScores = false
            if (@filter) then
              if((@naGroup == 100 and !(xNA and yNA)) or !(xNA or yNA)) then
                printScores = true
              else
                #$stdout.puts "Skipped #{xNA} #{yNA} #{xScore} #{yScore}"
              end
            else
              printScores = true
            end
            if(printScores) then
              xPrimeWriter.puts(xScore)
              yPrimeWriter.puts(yScore)
              commonRegions += 1
            end
          }

          xPrimeWriter.close()
          yPrimeWriter.close()
          xReader.close()
          yReader.close()
          #raise "No Common regions found between #{xAxisTrk} and #{yAxisTrk}. Cannot compute correlation." if(commonRegions == 0)
          corrVal = 0
          if(commonRegions != 0)
            # Do we need to normalize?
            if(@normalization != 'none')
              # Will write out replacement data files. Keep unnormalized arround, at least temporarily.
              mvOut = `mv #{xcommonFile} #{xcommonFile}.raw 2>&1 `
              raise "ERROR: mv failed for #{xcommonFile} -> #{xcommonFile}.raw. Exit status: #{$?.exitstatus}; mv said:\n#{mvOut.inspect}" unless($?.success?)
              mvOut = `mv #{ycommonFile} #{ycommonFile}.raw 2>&1 `
              raise "ERROR: mv failed for #{ycommonFile} -> #{ycommonFile}.raw. Exit status: #{$?.exitstatus}; mv said:\n#{mvOut.inspect}" unless($?.success?)
              # Read raw data into GSL vectors
              xVec = GSL::Vector.alloc(commonRegions)
              yVec = GSL::Vector.alloc(commonRegions)
              xPrimeReader = File.open("#{xcommonFile}.raw")
              yPrimeReader = File.open("#{ycommonFile}.raw")
              commonRegions.times { |ii|
                xVec[ii] = xPrimeReader.readline.to_f
                yVec[ii] = yPrimeReader.readline.to_f
              }
              xPrimeReader.close()
              yPrimeReader.close()
              # Preform appropriate normalization of the 2 GSL::Vectors. The methods return the new vectors.
              xVec, yVec = ( @normalization == 'quant' ? BRL::Stats.quantileNormalize(xVec, yVec) : BRL::Stats.gaussianNormalize(xVec, yVec) )
              # Write out the replacement data (for R-based file-correlation mainly; don't want to pass these as Ruby arrays to @rUtil because may be HUGE, and if turned into Ruby Arrays, they will be A LOT BIGGER. GSL::Vector is pretty tight (N*8bytes of RAM for each vector); Ruby Array will not be.
              writer = File.open(xcommonFile, "w+")
              xVec.each { |val| writer.puts val }
              writer.close()
              writer = File.open(ycommonFile, "w+")
              yVec.each { |val| writer.puts val }
              writer.close()
            end
            # Compute correlation of values in xcommonFile and ycommonFile
            corrVal = @rUtil.fileCorrelation(xcommonFile, ycommonFile, :V1, @simFun.to_sym)
          end
          #corrVal = GSL::Stats::correlation(xVec, yVec) # <- old, pearson only
          matrixHash["#{trkUrl}_#{xAxisTrkUrl}"] = corrVal
          matrixHash["#{xAxisTrkUrl}_#{trkUrl}"] = corrVal
        }
      }
      mf = File.open('matrix/matrix.txt', 'w')
      mf.print("X")
      @xAxisTrks.each_key { |xAxisTrkUrl|
        trkName = @trkApiHelper.extractName(xAxisTrkUrl)
        mf.print("\t#{trkName}")
      }
      mf.print("\n")
      longerListHash = {} # Make the order same as the older wrapper
      longerListTrks.each { |trk|
        longerListHash[trk['url']] = nil
      }
      longerListHash.each_key { |trkUrl|
        yAxisTrk = @trkApiHelper.extractName(trkUrl)
        mf.print(yAxisTrk)
        @xAxisTrks.each_key { |xAxisTrkUrl|
          mf.printf("\t%6f","#{matrixHash["#{trkUrl}_#{xAxisTrkUrl}"]}")
        }
        mf.print("\n")
      }
      mf.close()
    end

    def makeTrackNameNewickSafe(trackName)
      return trackName.gsub(/:/,"|").gsub(/ /,"_").gsub(/[^\|_\w]/,"")
    end

    def runHeatMapTool()
      ##Reverse order Color schene
      #@color = "#5E4FA2,#3288BD,#66C2A5,#ABDDA4,#E6F598,#FFFFBF,#FEE08B,#FDAE61,#F46D43,#D53E4F,#9E0142"
      $stderr.debugPuts(__FILE__, __method__, "Running", "HeatMap Tool")
      `mkdir -p logs`
      cmd = "drawHeatMap.rb -i #{@scratch}/matrix/matrix.txt -o #{@scratch} -d #{@dendogram} -f #{@distFun} -h #{@hclustFun} -k #{@key} "
      cmd << "-y #{@density} -c #{@color} "
      cmd << " -S " if(@forceSquare)
      cmd << " > #{@scratch}/logs/heatmapTool.log 2>#{@scratch}/logs/heatmapTool.error.log "
      exitStatus = EXIT_OK
      $stderr.debugPuts(__FILE__, __method__, "Heatmap tool command ", cmd)
      system(cmd)
      if($?.exitstatus != 0)
        raise "Error: Problem encountered creating heatmap after generating matrix file."
      else
        $stderr.debugPuts(__FILE__, __method__, "Done", "HeatMap Tool")
        # Wrap heatmap svg in HTML, add controls, scale to viewport
        htmlWrapSVGFile("matrix.txt.fixed.heatmap.svg", "surface1", 800, 800)
        # Wrap corrplot svg in HTML, add controls, scale to viewport
        htmlWrapSVGFile("matrix.txt.fixed.corrplot.svg", "surface6", 800, 800)
        # Graphlan rendering of tree images
        makeTreeImages()
      end
    end

    def getTrackAttrHash(trkUrls)
      trkDbList = getTracksByDB(trkUrls)
      trkAttrList = getAttributesForTracksByDb(trkDbList)
      return trkAttrList
    end

    def makeTreeImages()
      rowNewickFile = "rows.newick.txt"
      colNewickFile = "columns.newick.txt"

      if(File.exists?(rowNewickFile) and File.exists?(colNewickFile)) then
        # Format newick node names to remove : which is a part of track name
        # Most newick programs fail to parse this since : is also used to indicate branch length in Newick
        # Map track names to make them newick safe. The map files will also be uploaded with the results so they can be used to work with the newicks produced from this tool
        rowString = CGI.escape(File.read(rowNewickFile))
        trackUrls = []
        newickNameHash = {}
        mapfh = File.open("trackMap.txt","w")
        @yAxisTrks.each {|yurl|
          trkName = @trkApiHelper.extractName(yurl)
          nsTrkName = makeTrackNameNewickSafe(trkName)
          newickNameHash[trkName] = nsTrkName
          mapfh.puts("#{trkName}\t#{nsTrkName}\t#{yurl}")
          rowString.gsub!(/#{CGI.escape(trkName)}/,CGI.escape(nsTrkName))
          trackUrls << yurl
          }
        rfh=File.open(rowNewickFile,"w"); rfh.print CGI.unescape(rowString);rfh.close();
        colString = CGI.escape(File.read(colNewickFile))
        @xAxisTrks.each_key {|xurl|
          trkName = @trkApiHelper.extractName(xurl)
          nsTrkName = makeTrackNameNewickSafe(trkName)
          newickNameHash[trkName] = nsTrkName
          trackUrls << xurl unless (trackUrls.member?(xurl))
          mapfh.puts("#{trkName}\t#{nsTrkName}\t#{xurl}")
          colString.gsub!(/#{CGI.escape(trkName)}/,CGI.escape(nsTrkName))
          }
        mapfh.close
        cfh=File.open(colNewickFile,"w"); cfh.print CGI.unescape(colString);cfh.close();
        trackAttrList = getTrackAttrHash(trackUrls)
        generateAttributeListing(trackAttrList, newickNameHash, "trackInfo.txt")
        produceGraphlanImages(rowNewickFile)
        produceGraphlanImages(colNewickFile)
        $stderr.debugPuts(__FILE__, __method__, "Done", "Creating Graphlan visualizations")
      end
    end

    def getTracksByDB(trackUrlList)
      dbList = {}
      trackUrlList.each { |trackUrl|
        dbUrl = @dbhelper.extractPureUri(trackUrl)
        trkName = @trkhelper.extractName(trackUrl)
        if(!dbList.has_key?(dbUrl))
          dbList[dbUrl] = []
        end
        dbList[dbUrl] << trkName
      }
      return dbList
    end

    def getAttributesForTracksByDb(dbList)
      hostAuthMap = BRL::Genboree::Abstract::Resources::User.getHostAuthMapForUserId(nil,@userId)
      gbu = BRL::Genboree::GeneViewer::GBTrackUtil.new(hostAuthMap)
      attrResult = gbu.getAllEntitiesMulti(:trk, dbList.keys, [], 0)
      trkList = {}
      dbList.each_key { |db|
        attrs = attrResult[db]
        trkNames = dbList[db]
        attrs.each { |trackAttr|
          if(trkNames.member?(trackAttr[0]))
            trkList[trackAttr[0]] = trackAttr[1]
          end
        }
      }
      return trkList
    end

    def generateAttributeListing(trackAttrList, newickNameHash, fileName)
      attrTracks = {}
      attrNames = Hash.new(0)
      trackAttrList.each_key { |track|
        ta = trackAttrList[track]
        attrTracks[track] = {}
        ta.each_key { |attrName|
          if(attrName !~ /^gb/)
            attrNames[attrName] += 1
            attrTracks[track][attrName] = ta[attrName]
          end
        }
      }
      ofh = File.open(fileName,"w")
      if(attrNames.keys.empty?)
        ofh.print "No attributes found"
      else
        ofh.print "Track\tNewick Name\t"
        ofh.print attrNames.keys.sort.join("\t")
        ofh.print "\n"
        trackAttrList.keys.sort.each{|track|
          ofh.print "#{track}\t#{newickNameHash[track]}"
          attrNames.keys.sort.each{|attr|
            ofh.print("\t")
            attrVal = attrTracks[track][attr]
            if(attrVal.nil?)
              ofh.print "NoValue"
            else
              ofh.print attrVal
            end
          }
          ofh.print("\n")
        }
      end
      ofh.close()
    end

    def transformSVGContent(svgString, maxHeight=800, maxWidth=800, gid="figure_1")
      # Need to FIRST find which dimension needs the MOST scaling
      # Apply that 1 scaling ratio to BOTH dimensions.
      # . This KEEPS THE ASPECT RATIO!
      # . This works even when maxHeight != maxWidth (say, target viewport is 16:9 or 4:3 instead of 1:1 or something)

      # Get original height
      svgString   =~ /(<svg[^>]+)height\s*=\s*"([^"]+)"/
      hOrig       = $2.gsub(/\D/, '').to_f
      hScale      = maxHeight / hOrig

      # Get original width
      svgString =~ /(<svg[^>]+)width\s*=\s*"([^"]+)"/
      wOrig       = $2.gsub(/\D/, '').to_f
      wScale      = maxWidth / wOrig

      # We want use the smallest of the 2 scales.
      # . largest original dim has to scale down a lot (small scale) to meet its target
      # . largest original dim has to scale up a little (small scale) to meet its target
      # Also need to scale the viewport dimension for the smallest dim
      if(hScale < wScale)
        scale = hScale
      else # wScale < hScale
        scale = wScale
      end

      # Replace orig height with correct viewport height. Must repeat regexp since we'll be changing some chars matched.
      svgString   =~ /(<svg[^>]+)height\s*=\s*"([^"]+)"/
      hFullMatch  = $~[0]
      hPrefix     = $1
      svgString.gsub!(hFullMatch, "#{hPrefix}height=\"#{maxHeight}px\"")
      # Replace orig width with viewport width
      svgString =~ /(<svg[^>]+)width\s*=\s*"([^"]+)"/
      wFullMatch  = $~[0]
      wPrefix     = $1
      svgString.gsub!(wFullMatch, "#{wPrefix}width=\"#{maxWidth}px\"")

      # Get rid of all viewbox attributes
      svgString.gsub!(/viewBox\s*=\s*"[^"]+"/, '')

      # Add in a transform attribute to the appropriate <g> elem
      # - remove transform attribute from <g> we care about, even if (a) stuff between <g and id attribute, (b) stuff between id attr and transform attr
      fullMatch  = nil
      if(svgString =~ /(<g[^>]+id\s*=\s*"#{gid}"[^>]+)transform\s*=\s*"[^"]+"/)
        fullMatch  = $~[0]
      else # try viewBox before id just to be sure
        if(svgString =~ /(<g[^>]+transform\s*=\s*"[^"]+"[^>]+id\s*=\s*"#{gid}")/)
          fullMatch  = $~[0] if($~)
        end
      end
      if(fullMatch) # then the <g> we are concerned about has a viewBox attr! deal with.
        removed = fullMatch.gsub(/transform\s*=\s*"[^"]+"/, ' ')
        svgString.gsub!(fullMatch, removed)
      end

      # - add in a replacement transform attribute to relevant <g>
      svgString =~ /(<g[^>]+id\s*=\s*"#{gid}")/
      prefix = $1
      svgString.gsub!(/(<g[^>]+id\s*=\s*"#{gid}")/, "#{prefix} transform=\"matrix(#{scale} 0 0 #{scale} 0 0)\"")

      return svgString
    end

    def getCompassCoords(svgString, vpos, hpos, offset=50)
      svgString =~ /<svg[^>]+height\s*=\s*"([^"]+)"/
      origHeight = $1.gsub(/\D/, '').to_i
      svgString =~ /<svg[^>]+width\s*=\s*"([^"]+)"/
      origWidth = $1.gsub(/\D/, '').to_i
      cx = offset
      cy = offset
      if(vpos == :bottom)
        cy = origHeight - offset
      end
      if(hpos == :right)
        cx = origWidth - offset
      end
      return [cx, cy]
    end

    def addSVGCompass(svgString, imageId, vpos, hpos)
      (cx, cy) = getCompassCoords(svgString,vpos,hpos)
      jsString = "<script type=\"text/javascript\" src=\"/javaScripts/workbench/d3/d3.brl.js\"> </script><script type=\"text/javascript\" src=\"/javaScripts/workbench/d3/helpers.js\"> </script>"
      svgString.gsub!(/<svg /, "#{jsString}<svg ")
      svgString.gsub!(/<\/svg>/, "#{BRL::Genboree::Graphics::D3::D3.controller(cx, cy, 'controllerG', imageId)}</svg>")
      return svgString
    end

    def processSVG(svgFileName, addCompass=true, transform=true, gid="surface1")
      svgContent = File.read(svgFileName)
      # Rescale the SVG to completely fit within a fixed viewport
      if(transform)
        svgContent = transformSVGContent(svgContent, 800, 800, gid)
      end
      # Add the controls
      if(addCompass)
        svgContent = addSVGCompass(svgContent, gid, :top, :right)
      end
      # Wrap as html
      html = htmlWrapSVG(svgContent)
      # Write to html file
      ff = File.open("#{svgFileName}.html", 'w')
      ff.print(html)
      ff.close()
      return html
    end

    def htmlWrapSVG(svgContent)
      # Remove the <?xml> metatag if present
      svgContent.gsub!(/<\?xml[^>]+\?>/, '')
      html = "<html><head></head><body>\n\n#{svgContent}\n\n</body></html>"
      return html
    end

    def htmlWrapSVGFile(svgFileName, imageGid, viewportWidth=800, viewportHeight=800)
      svgContent = File.read(svgFileName)
      # - transform by changing viewport size, removing viewBox, adding appropriate transform(), etc
      svgContent = transformSVGContent(svgContent, viewportWidth, viewportHeight, imageGid)
      # - add the controls
      svgContent = addSVGCompass(svgContent, imageGid, :top, :right)
      # - wrap in real html
      svgContent = htmlWrapSVG(svgContent)
      fh = File.open("#{svgFileName}.html", "w+")
      fh.print svgContent
      fh.close
      return true
    end

    def produceGraphlanImages(newickFileName)
      treeFileNames = []
      scaleFileName = "#{newickFileName}.scaled"
      treeFileNames << scaleFileName
      nlogFileName = "#{newickFileName}.nlog"
      treeFileNames << nlogFileName
      log10FileName = "#{newickFileName}.log10"
      treeFileNames << log10FileName
      eqFileName = "#{newickFileName}.eq"
      treeFileNames << eqFileName

      newickScaler = BRL::Genboree::Graphics::NewickScaler.new(newickFileName)
      newickScaler.minScaleTree(scaleFileName,10)
      newickScaler.logScaleTree(nlogFileName,10)
      newickScaler.logScaleTree(log10FileName,10,10)
      newickScaler.equiScaleTree(eqFileName,10)

      treeFileNames.each { |treeFileName|
        graphlanViewer = BRL::Genboree::Graphics::GraphlanViewer.new(treeFileName)
        annotFileName = "#{treeFileName}.annot"
        graphlanViewer.generateAnnotationFile(annotFileName)
        imageFileName = "#{treeFileName}.png"
        graphlanViewer.drawGraphlanImage(treeFileName, annotFileName, imageFileName ,"#{@scratch}/logs/#{imageFileName}.graphlan.log")
        # - convert to cropped version to deal with any oversizing due to above graphlan sizing calcs in R.
        `convert #{imageFileName} -trim -bordercolor white -border 10x10 -verbose #{imageFileName}`
        imageFileName = "#{treeFileName}.svg"
        graphlanViewer.drawGraphlanImage(treeFileName, annotFileName, imageFileName, "#{@scratch}/logs/#{imageFileName}.graphlan.log")
        processSVG(imageFileName, true, true, "figure_1")
      }
    end

    # Downloads shorter (X-axis) list of tracks using threads
    # [+returns+] nil
    def downloadShorterList(roiTrack)
      t1 = Time.now
      retVal = true
      @xAxisTrks = {}
      regions = roiTrack ? roiTrack : @resolution
      uriFileHash = {}
      $stderr.puts "@tracksSummaryHash:\n#{@tracksSummaryHash.inspect}"
      @tracksSummaryHash.each_key { |list|
        if(list == @entityNameWithLessTrks)
          @tracksSummaryHash[list][:total].each {|url|
            trkUrl = url['url']
            uriFileHash[trkUrl] = SHA1.hexdigest(trkUrl) if(!@tracksSummaryHash[list][:missing].has_key?(trkUrl))
          }
        end
      }
      #shorterListTrks.each { |url|
      #  trkUrl = url['url']
      #  uriFileHash[trkUrl] = SHA1.hexdigest(trkUrl)
      #}

      ptd = BRL::Genboree::Helpers::ParallelTrackDownload.new(uriFileHash, @userId)
      ptd.regions = regions
      ptd.emptyScoreValue = 'n/a'
      ptd.spanAggFunction = @span
      ptd.downloadTracksUsingThreads()
      uriFileHash.each_key { |uri|
        fileName = uriFileHash[uri]
        raise "Could not download track: #{uri}" if(!File.exists?(fileName))
        exp = BRL::Util::Expander.new(fileName)
        exp.extract()
        `cut -f4 #{exp.uncompressedFileName} > #{fileName}.scores`
        `rm -f #{exp.uncompressedFileName}`
        @xAxisTrks[uri] = "#{fileName}.scores"
      }
      $stderr.debugPuts(__FILE__,__method__,"Total time to download shorter list of tracks", Time.now - t1)
    end

    # Made more generic by accepting src and dest filepaths (dest path is rooted at job folder)
    # Sriram Raghuraman 09-25-12
    def uploadUsingAPI(jobName,srcFilePath,destFilePath)
      @exitCode = 0
      restPath = @outPath
      path = restPath +"/file/EpigenomicExpHeatmap/#{CGI.escape(jobName)}/#{destFilePath}/data"
      path << "gbKey=#{@dbApiHelper.extractGbKey(@outputs[0])}" if(@dbApiHelper.extractGbKey(@outputs[0]))
      @apicaller.setRsrcPath(path)
      infile = File.open(srcFilePath,"r")
      @apicaller.put(infile)
      infile.close
      if @apicaller.succeeded?
        $stderr.debugPuts(__FILE__, __method__, "SUCCESS", "Uploaded file #{srcFilePath} to #{destFilePath}")
        @exitCode = 0
      else
        @errUsrMsg = "Failed to upload #{srcFilePath} to #{destFilePath} file "
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "#{@errUsrMsg}")
        $stderr.debugPuts(__FILE__, __method__, "DEBUG", "@apiCaller.respBody:#{@apicaller.respBody.inspect}")
        @exitCode = 118
      end
      return @exitCode
    end

    # Runs svd script
    # [+returns+] nil
    def computeSVD()
      $stderr.debugPuts(__FILE__, __method__, "Running", "SVD computation")
      cmd = "computeSVD.rb -i #{@scratch}/matrix.txt.fixed -o #{@scratch}"
      cmd << " > #{@scratch}/logs/svdTool.log 2>#{@scratch}/logs/svdTool.error.log "
      exitStatus = EXIT_OK
      $stderr.debugPuts(__FILE__, __method__, "SVD tool command ", cmd)
      system(cmd)
      if($?.exitstatus != 0)
        raise "Could not compute SVD."
      else
        $stderr.debugPuts(__FILE__, __method__, "Done", "SVD Tool")
      end
      $stderr.debugPuts(__FILE__, __method__, "Status", "SVD tool completed with #{exitStatus}")
    end

    # Transfer generated file to target database
    # [+returns+] exitStatus
    def uploadData()
      exitStatus = 0
      @apicaller = WrapperApiCaller.new(@outHost,"",@userId)
      restPath = @outPath
      filePref = "matrix.txt.fixed"
      attrNames = ["JobToolId", "CreatedByJobName"]
      attrVals = [ @toolId, "http://#{@submitHost}/REST/v1/job/#{@jobId}" ]

      uploadUsingAPI(@analysis, "#{filePref}.heatmap.svg", "heatmap.svg")
      uploadUsingAPI(@analysis, "#{filePref}.corrplot.svg", "corrplot.svg")
      uploadUsingAPI(@analysis, "#{filePref}.heatmap.png", "heatmap.png")
      uploadUsingAPI(@analysis, "#{filePref}.corrplot.png", "corrplot.png")
      uploadUsingAPI(@analysis, filePref, "matrix.txt")

      setFileAttrs(restPath +"/file/EpigenomicExpHeatmap/#{CGI.escape(@analysis)}/heatmap.svg", attrNames, attrVals)
      setFileAttrs(restPath +"/file/EpigenomicExpHeatmap/#{CGI.escape(@analysis)}/corrplot.svg", attrNames, attrVals)
      setFileAttrs(restPath +"/file/EpigenomicExpHeatmap/#{CGI.escape(@analysis)}/heatmap.png", attrNames, attrVals)
      setFileAttrs(restPath +"/file/EpigenomicExpHeatmap/#{CGI.escape(@analysis)}/corrplot.png", attrNames, attrVals)
      setFileAttrs(restPath +"/file/EpigenomicExpHeatmap/#{CGI.escape(@analysis)}/matrix.txt", attrNames, attrVals)

      if($?.exitstatus != 0)
        exitStatus = 118
      else
        filePref << ".svd"
        if(File.exists?("#{filePref}.U.txt") and File.exists?("#{filePref}.D.txt") and File.exists?("#{filePref}.V.txt"))
          uploadUsingAPI(@analysis,"#{filePref}.U.txt","svd/matrix.svd.U.txt")
          uploadUsingAPI(@analysis,"#{filePref}.D.txt","svd/matrix.svd.D.txt")
          uploadUsingAPI(@analysis,"#{filePref}.V.txt","svd/matrix.svd.V.txt")
        end
        if(File.exists?("rows.newick.txt") and File.exists?("columns.newick.txt"))
          uploadUsingAPI(@analysis,"rows.newick.txt","newick/rows.newick.txt")
          uploadUsingAPI(@analysis,"columns.newick.txt","newick/columns.newick.txt")
          setFileAttrs(restPath +"/file/EpigenomicExpHeatmap/#{CGI.escape(@analysis)}/newick/rows.newick.txt",attrNames,attrVals)
          setFileAttrs(restPath +"/file/EpigenomicExpHeatmap/#{CGI.escape(@analysis)}/newick/columns.newick.txt",attrNames,attrVals)
          exts = ["png","svg.html"]
          rowFileNames = ["rowsScaled","rowslogn","rowslog10","rowseq"]
          exts.each {|ee|  rowFileNames.each {|rr| uploadUsingAPI(@analysis,"#{rr}.#{ee}","newick/#{rr}.#{ee}") }}
          colFileNames = ["columnsScaled","columnslogn","columnslog10","columnseq"]
          exts.each {|ee|  colFileNames.each {|cc| uploadUsingAPI(@analysis,"#{cc}.#{ee}","newick/#{cc}.#{ee}") }}
          uploadUsingAPI(@analysis,"trackInfo.txt","trackInfo.txt")
          setFileAttrs(restPath +"/file/EpigenomicExpHeatmap/#{CGI.escape(@analysis)}/trackInfo.txt",attrNames,attrVals)
          uploadUsingAPI(@analysis,"trackMap.txt","trackMap.txt")
          setFileAttrs(restPath +"/file/EpigenomicExpHeatmap/#{CGI.escape(@analysis)}/trackMap.txt",attrNames,attrVals)
          trackMapURI = "http://#{@submitHost}#{restPath}/file/EpigenomicExpHeatmap/#{CGI.escape(@analysis)}/trackMap.txt"
          trackMapAttr = "TrackMapFile"
          setFileAttrs(restPath +"/file/EpigenomicExpHeatmap/#{CGI.escape(@analysis)}/newick/rows.newick.txt",[trackMapAttr],[trackMapURI])
          setFileAttrs(restPath +"/file/EpigenomicExpHeatmap/#{CGI.escape(@analysis)}/newick/columns.newick.txt",[trackMapAttr],[trackMapURI])
        end
      end
      return exitStatus
    end

    # Used to store job specific info. as attrs on uploaded files
    def setFileAttrs(fileRsrcPath,attrNames, attrValues)
      apiCaller = WrapperApiCaller.new(@outHost,"",@userId)
      rsrcPath = "#{fileRsrcPath}/attribute/{attribute}/value"
      rsrcPath << "?gbKey=#{@dbhelper.extractGbKey(@output)}" if(@dbhelper.extractGbKey(@output))
      apiCaller.setRsrcPath(rsrcPath)
      attrNames.each_index{|ii|
        payload = { "data" => { "text" => attrValues[ii]}}
        apiCaller.put({:attribute => attrNames[ii]},payload.to_json)
        if(!apiCaller.succeeded?) then
          errMsg = "Unable to set #{attrNames[ii]} attribute of #{fileRsrcPath}\n#{apiCaller.respBody}"
          $stderr.debugPuts(__FILE__, __method__, "Failure setting attributes", errMsg)
          raise errMsg
        end
      }
    end

    # Prepares success email object
    # [+emailObject+] An instance of the WrapperEmail class
    def prepSuccessEmail()
      emailObject               = BRL::Genboree::Tools::WrapperEmailer.new(@toolTitle,@userEmail,@jobId)
      emailObject.userFirst     = @firstName
      emailObject.userLast      = @lastName
      emailObject.analysisName  = @analysis
      inputsText                = buildSectionEmailSummary(@inputs)
      emailObject.inputsText    = inputsText
      outputsText               = buildSectionEmailSummary(@outputs)
      emailObject.outputsText   = outputsText
      emailObject.settings      = @jobConf['settings']
      emailObject.exitStatusCode = @exitCode
      prj =  @outputs[1].split(/\/prj\//)
      prj[1].chomp!('?')
      uriOutput   = URI.parse(@outputs[1])
      @hostOutput = uriOutput.host
      emailObject.resultFileLocations = "http://#{@hostOutput}/java-bin/project.jsp?projectName=#{prj[1]}"
      additionalInfo = ""
      @tracksSummaryHash.each_key { |list|
        if(!@tracksSummaryHash[list][:missing].empty?)
          additionalInfo << "\n\nThe following tracks from the entity list: #{list} were skipped from the heatmap because of inaccessibility or no data:\n\n"
          @tracksSummaryHash[list][:missing].each_key { |trkUrl|
            additionalInfo << " * #{@trkApiHelper.extractName(trkUrl)}\n"  
          }
        end
      }
      emailObject.additionalInfo = additionalInfo if(!additionalInfo.empty?)
      return emailObject
    end

    # Prepares failure email object
    # [+emailObject+] An instance of the WrapperEmail class
    def prepErrorEmail()
      emailObject               = BRL::Genboree::Tools::WrapperEmailer.new(@toolTitle,@userEmail,@jobId)
      emailObject.userFirst     = @firstName
      emailObject.userLast      = @lastName
      emailObject.analysisName  = @analysis
      inputsText                = buildSectionEmailSummary(@inputs)
      emailObject.inputsText    = inputsText
      outputsText               = buildSectionEmailSummary(@outputs)
      emailObject.outputsText   = outputsText
      emailObject.settings      = @jobConf['settings']
      emailObject.errMessage    = @errUsrMsg
      emailObject.exitStatusCode = @exitCode
      additionalInfo = ""
      @tracksSummaryHash.each_key { |list|
        if(!@tracksSummaryHash[list][:missing].empty?)
          additionalInfo << "\n\nThe following tracks from the entity list: #{list} were found to be inaccessible or had no data:\n\n"
          @tracksSummaryHash[list][:missing].each_key { |trkUrl|
            additionalInfo << " * #{@trkApiHelper.extractName(trkUrl)}\n"  
          }
        end
      }
      emailObject.additionalInfo = additionalInfo if(!additionalInfo.empty?)
      return emailObject
    end

    # ------------------------------------------------------------------
    # SCRIPT-SPECIFIC METHODS
    # ------------------------------------------------------------------
    # - stuff needed to do actual program or drive 3rd party tools, etc
    # - repeatedly-used generic stuff is in library classes of course...

    def processJobConf()
      @inputs     = @jobConf['inputs']
      @outputs    = @jobConf['outputs']
      apiUriHelper = BRL::Genboree::REST::Helpers::ApiUriHelper.new()
      if(apiUriHelper.extractType(@outputs[0]) != "db" )
        @outputs.reverse!
      end
      @span       = @jobConf['settings']['spanAggFunction']
      @filter     = @jobConf['settings']['removeNoDataRegions']
      @lastRoi    = @jobConf['settings']['lastTrkROI']
      @normalization  = (@jobConf['settings']['normalization'] or "quant")
      @analysis   = @jobConf['settings']['analysisName']
      @dendogram  = (@jobConf['settings']['dendograms'] or "both")
      @simFun     = (@jobConf['settings']['simFun'] or "pearson")
      @distFun    = (@jobConf['settings']['distfun'] or "euclidean")
      @hclustFun  = (@jobConf['settings']['hclustfun'] or "complete")
      @key        = @jobConf['settings']['key']
      @key        = ((@key and @key.strip =~ /TRUE/i) ? "TRUE" : "FALSE")
      @density    = (@jobConf['settings']['density'] or "density")
      @naGroup    = @jobConf['settings']['naGroup']
      @forceSquare = @jobConf['settings']['forceSquare']
      @forceSquare = ((@forceSquare and @forceSquare.strip =~ /TRUE/i) ? true : false)
      @color      = (@jobConf['settings']['colors'] or 'Spectral')
      @replaceNAValue = @jobConf['settings']['replaceNAValue']
      if(@filter)
        if (@naGroup == "0" or @naGroup == "100") then
          @naGroup = @naGroup.to_f
        else
          raise "Invalid value for naGroup: #{@naGroup}"
        end
      end
      @gbConfig   = @jobConf['context']['gbConfFile']
      @userEmail  = @jobConf['context']['userEmail']
      @adminEmail = @jobConf['context']['gbAdminEmail']
      @firstName  = @jobConf['context']['userFirstName']
      @lastName   = @jobConf['context']['userLastName']
      @scratch    = @jobConf['context']['scratchDir']
      @apiDBRCkey = @jobConf["context"]["apiDbrcKey"]
      @jobId      = @jobConf["context"]["jobId"]
      @userId     = @jobConf['context']['userId']
      @toolId       = @jobConf["context"]["toolIdStr"]
      @submitHost   = @jobConf["context"]["submitHost"]
      @analysisNameEsc = CGI.escape(@analysis)
      # Retreiving group and database information from the input trkSet
      @grph 	  = BRL::Genboree::REST::Helpers::GroupApiUriHelper.new(@gbConfig)
      @dbhelper   = BRL::Genboree::REST::Helpers::DatabaseApiUriHelper.new(@gbConfig)
      @trkhelper  = BRL::Genboree::REST::Helpers::TrackApiUriHelper.new(@gbConfig)
      dbrc 	    = BRL::DB::DBRC.new(nil, @apiDBRCkey)
      @pass 	  = dbrc.password
      @user 	  = dbrc.user
      @tempOutputArray = []
      if(@outputs[0] !~ (BRL::Genboree::REST::Helpers::DatabaseApiUriHelper::NAME_EXTRACTOR_REGEXP))
        @tempOutputArray[0] = @outputs[1]
        @tempOutputArray[1] = @outputs[0]
        @outputs = @tempOutputArray
      end
      # Output databse information to upload the heatmap in file area
      uri         = URI.parse(@outputs[0])
      @outHost    = uri.host
      @outPath    = uri.path
      case @jobConf["settings"]["fixedResolution"]
      when "high"
        @resolution = 1000
      when "medium"
        @resolution = 10000
      when "low"
        @resolution = 100000
      else
        @resolution = 10000
      end
      return EXIT_OK
    end
  end
end ; end; end; # module BRL ; module Script

########################################################################
# MAIN - Provided in the scripts that implement ScriptDriver sub-classes
# - but would look exactly like this ONE LINE:
########################################################################
# IF we are running this file (and not using it as a library), run it:
puts __FILE__
if($0 and File.exist?($0) )
  # Argument to main() is your specific class:
  BRL::Genboree::Tools::main(BRL::Genboree::Tools::WrapperEpigenomeHeatmap)
end
