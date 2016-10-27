#!/usr/bin/env ruby

require 'RMagick'
require 'json'
require 'fileutils'
require "brl/util/util"
require "brl/genboree/genboreeUtil"
require "brl/genboree/rest/apiCaller"
require 'brl/genboree/dbUtil'
require "brl/db/dbrc"
require 'brl/genboree/graphics/barGlyph.rb'
require 'brl/genboree/abstract/resources/annotationFile'
require 'brl/genboree/abstract/resources/lffFile'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/geneViewer/geneElementsUtil'
require 'brl/genboree/geneViewer/gbTrackUtilNew'

module BRL ; module Genboree ; module Graphics
  class GeneImageCreator
    attr_accessor :colorAttr, :typeAttr, :nameAttr, :annoFileObj
    attr_accessor :rackEnv
    attr_accessor :hostAuthMap

    def initialize(colorAttr=nil, typeAttr=nil, nameAttr=nil, genbConf=nil,hostAuthMap=nil)
      @genbConf = genbConf
      if(@genbConf.nil?)
        @genbConf = genbConf = BRL::Genboree::GenboreeConfig.load()
      end
      @apiDbrc = BRL::DB::DBRC.new(@genbConf.dbrcFile, @genbConf.geneImagesDbrcKey)
      @colorAttr = colorAttr
      @typeAttr = typeAttr
      @nameAttr = nameAttr
      @rackEnv = nil
      @imageType = nil
      @apiHost = @apiDbrc.driver.split(/:/).last.strip
      @hostAuthMap = hostAuthMap
      @apiCaller = BRL::Genboree::REST::ApiCaller.new(@apiHost,"",@hostAuthMap)

      #@apiCaller.setLoginInfo(@apiDbrc.user, @apiDbrc.password)
      #$stderr.debugPuts(__FILE__, __method__, "hqe","#{Time.now-t1} initialized gic")
    end



    def createSampleBarGraph(annoName, scrTrack, roiTrack, configString)
      retVal = nil
      aggFunction = "avgByLength"
      
      lffLines = extractAnnoLines(annoName, scrTrack, roiTrack, aggFunction)
      
      if(!lffLines.nil? ) then
        lffLines = lffLines.lines.entries.map{|xx| xx.split(/\t/)}
        retVal = setUpSampleGraph(lffLines, configString)
      end
      return retVal
    end



    def createSampleAvgBarGraph(annoName, scrTracks, roiTrack, configString)
      retVal = nil
      aggFunction = "avgByLength"
      trackCount = 0
      summedLines = []
      #$stderr.debugPuts(__FILE__, __method__, "hqe","#{Time.now-t1} avg graph preprocessing done")
      scrTracks.each{|track|
        lffLines = extractAnnoLines(annoName, track, roiTrack, aggFunction)
        #$stderr.debugPuts(__FILE__, __method__, "hqq","#{track} #{annoName}")
        if(!lffLines.nil? ) then
          if(summedLines.empty?) then
            lffLines.lines.entries.each_with_index{|line,ii|
              summedLines << line.chomp.split(/\t/)
              summedLines[ii][9] = summedLines[ii][9].to_f
            }
          else
            lffLines.lines.entries.each_with_index{|line,ii|
              summedLines[ii][9] += line.chomp.split(/\t/)[9].to_f
            }
          end
          trackCount += 1
        end
      }
      if(!summedLines.nil?) then
        summedLines.each{|sline| sline[9] /= trackCount.to_f}
        retVal = setUpSampleGraph(summedLines, configString)
      end
      return retVal
    end


    def createAnnoBarGraph(annoName, scrTrack, roiTrack, configString)
      retVal = nil
      aggFunction = nil
      @imgType = nil
      #lffLines = extractLffAnnos(geneName, trackName)
      # TODO: put back for internal request testing:
      aggFunction = "avgByLength"
      @imgType = :readDensity
      dbHelper = BRL::Genboree::REST::Helpers::DatabaseApiUriHelper.new
      trackHelper = BRL::Genboree::REST::Helpers::TrackApiUriHelper.new
      trackDb = dbHelper.extractPureUri(scrTrack)
      trackName = trackHelper.extractName(scrTrack)
      rcovTrack = @gbTrackUtil.getTrackListAttributesMulti("#{trackDb}?#{URI.parse(scrTrack).query}",trackName,["rcovTrack"])[trackName]
      if(!rcovTrack.nil?)
        rcovTrack = rcovTrack["rcovTrack"]
        aggFunction = "avg"
        @imgType = :methylation
      end
      
      lffLines = extractAnnoLines(annoName, scrTrack, roiTrack, aggFunction)
      
      rcLines = nil
      if(@imgType == :methylation) then
        # Get Read coverage information for methylation track. 'Regular' track only gives coefficient info.
        rcLines = extractAnnoLines(annoName, rcovTrack, roiTrack, aggFunction)
        rcLines = rcLines.lines.entries.map{|xx| xx.split(/\t/)}
      end
      #stdevLines = extractGeneElements(geneName, trackName, "stdev")
      if(!lffLines.nil? ) then
        lffLines = lffLines.lines.entries.map{|xx| xx.split(/\t/)}
        retVal = setUpAnnoGraph(lffLines, rcLines, nil, configString)
        #$stderr.debugPuts(__FILE__, __method__, "hqe","#{Time.now-t1} single bargraph done #{trackName}")
      end
      #$stderr.debugPuts(__FILE__, __method__, "hqe","#{Time.now-t1} single graph postprocessing done")
      return retVal
    end


    def createAnnoAvgBarGraph(annoName, scrTracks, roiTrack, configString)
      retVal = nil
      aggFunction = nil
      @imgType = nil
      aggFunction = "avgByLength"
      @imgType = :readDensity
      dbHelper = BRL::Genboree::REST::Helpers::DatabaseApiUriHelper.new
      trackHelper = BRL::Genboree::REST::Helpers::TrackApiUriHelper.new
      isMethylation = false
      rcovTracks = {}
      scrTracks.each{|scrTrack|
        trackDb = dbHelper.extractPureUri(scrTrack)
        trackName = trackHelper.extractName(scrTrack)
        rcovTrack = @gbTrackUtil.getTrackListAttributesMulti("#{trackDb}?#{URI.parse(scrTrack).query}",trackName,["rcovTrack"])[trackName]
        if(!rcovTrack.nil?) then
          rcovTrack = rcovTrack["rcovTrack"]
          isMethylation = true
          rcovTracks[scrTrack] = rcovTrack
        end
      }
      if(isMethylation) then
        aggFunction = "avg"
        @imgType = :methylation
      end
      trackCount = 0
      summedLines = []
      summedRCLines = []
      #$stderr.debugPuts(__FILE__, __method__, "hqe","#{Time.now-t1} avg graph preprocessing done")
      scrTracks.each{|track|
        
        lffLines = extractAnnoLines(annoName, track, roiTrack, aggFunction)
        
        #$stderr.debugPuts(__FILE__, __method__, "hqq","#{track} #{annoName}")
        if(!lffLines.nil? ) then
          if(summedLines.empty?) then
            lffLines.lines.entries.each_with_index{|line,ii|
              summedLines << line.chomp.split(/\t/)
              summedLines[ii][9] = summedLines[ii][9].to_f
            }
          else
            lffLines.lines.entries.each_with_index{|line,ii|
              summedLines[ii][9] += line.chomp.split(/\t/)[9].to_f
            }
          end
          trackCount += 1
          rcLines = nil
          if(@imgType == :methylation) then
            # Get Read coverage information for methylation track. 'Regular' track only gives coefficient info.
            rcLines = extractAnnoLines(annoName, rcovTracks[track], roiTrack, aggFunction)
            if(!rcLines.nil?) then
              if(summedRCLines.empty?) then
                rcLines.lines.entries.each_with_index{|line,ii|
                  summedRCLines << line.chomp.split(/\t/)
                  summedRCLines[ii][9] = summedRCLines[ii][9].to_f
                }
              else
                rcLines.lines.entries.each_with_index{|line,ii|
                  summedRCLines[ii][9] += line.chomp.split(/\t/)[9].to_f
                }
              end
            end
          end
        end
      }
      if(!summedLines.nil?) then
        summedLines.each{|sline| sline[9] /= trackCount.to_f}
        if(!summedRCLines.nil?) then
          summedRCLines.each{|sline| sline[9] /= trackCount.to_f}
        end
        retVal = setUpAnnoGraph(summedLines, summedRCLines, nil, configString)
      end
      return retVal
    end


    def setRackEnv(rackEnv)
      @rackEnv = rackEnv
      @gbTrackUtil = BRL::Genboree::GeneViewer::GBTrackUtil.new(@hostAuthMap)
      @gbTrackUtil.rackEnv = @rackEnv
      @gbTrackUtil.machineNameAlias = @genbConf.machineNameAlias
    end

    def createImage(annoName, scrTrack, roiTrack, imageFormat, configString)
      retval = nil
      if(imageFormat == :ANNO_BAR_GRAPH) then
        retval = createAnnoBarGraph(annoName, scrTrack[0], roiTrack, configString)
        #retval = createAnnoBarGraph(annoName, scrTrack, roiTrack, configString)
      elsif (imageFormat == :ANNO_AVG_BAR_GRAPH) then
        #$stderr.debugPuts(__FILE__, __method__, "DEBUG","#{Time.now} gcreate img start")
        retval =  createAnnoAvgBarGraph(annoName, scrTrack, roiTrack, configString)
      elsif(imageFormat == :SAMPLE_BAR_GRAPH) then
        retval = createSampleBarGraph(annoName, scrTrack[0], roiTrack, configString)
        #retval = createAnnoBarGraph(annoName, scrTrack, roiTrack, configString)
      elsif (imageFormat == :SAMPLE_AVG_BAR_GRAPH) then
        #$stderr.debugPuts(__FILE__, __method__, "DEBUG","#{Time.now} gcreate img start")
        retval =  createSampleAvgBarGraph(annoName, scrTrack, roiTrack, configString)
      else
        $stderr.puts "ERROR? Unknown image format specified: #{imageFormat}"
      end
      return retval
    end


    def setUpSampleGraph(lffLines, configString=nil)
      minValue = 0.001
      barArray = Array.new
      elementStrand = nil
      configHash = nil
      configNeeded = ! (configString.nil? or configString.empty?)
      if(configNeeded) then configHash = JSON.parse(CGI.unescape(configString)) end
      defaultColors = ["#d50000","#0000c0"]
      # Create bars from lff lines 1 per gene element
      lffLines.each_with_index { |line, ii|
        splitLine = line
        if(splitLine.size >= 10)
          elementStrand = splitLine[7]
          elementScore = splitLine[9].to_f.abs
          attrs = Hash.new
          if(splitLine.size > 12)
            avps = splitLine[12].gsub(/\s/, '').split(/;/) # gsub here not really necessary and could add slowness
            avps.each { |avp|
              (aa,vv) = avp.split(/=/)
              attrs[aa] = vv
            }
            elementColor = attrs[@colorAttr]
            elementType = attrs[@typeAttr]
            elementName = attrs[@nameAttr]
          else
            $stderr.puts "ERROR? The sample model line has no AVPs at all??? Line & fields:\n#{line.inspect}\n#{splitLine.inspect}"
          end
          # If no element color (direct or indirect via element type), go with black
          if(elementColor.nil? or elementColor !~ /#[a-f0-9]{6}/i)
            elementColor = defaultColors[ii%2]
          end
          elementInclude = true
          if(configNeeded)
            configVal = configHash[BRL::Genboree::GeneViewer::GeneElementsUtil::JSONELEMCODES[elementType]]
            if(configVal[0] == 'n') then
              elementInclude = false
            elsif(!configVal.include?(elementOrder) and configVal[0]!='a')
              elementInclude = false
            end
          end          
          if(elementInclude) then
            bar = BRL::Genboree::Graphics::Bar.new
            bar.score = elementScore
            bar.color = elementColor
            bar.type = elementType
            bar.name = elementName
          end
            barArray << bar
        else
          $stderr.puts "ERROR? The gene model line not LFF. Probably request error (missing resource?) Line & fields:\n#{line.inspect}\n#{splitLine.inspect}"
        end
      }
      # Handle negative strand genes
      if(elementStrand == '-')
        barArray = barArray.reverse
      end
      # max. score for scaling
      #maxScore = barArray.map{ |bb| if(bb.type != "Presence") then bb.score else 0 end}.max
      #if(maxScore < minValue) then
      #  maxScore = minValue
      #  
      #end
      maxScore = 1

      barArray.each{|bb|
        if(bb.type == "Presence")then
          if(bb.score == 0)
            bb.score = -1
          else
          bb.score = maxScore
        end
          
        end
        }
      bd = BRL::Genboree::Graphics::BarGlyphDrawer.new(barArray)
      bc = BRL::Genboree::Graphics::BarGlyphConfig.new
      bc.maxScore = maxScore

      bc.xlabel = "Metric Index"
      bc.minValue = minValue
      pngBlob = bd.draw(bc)
      return pngBlob
    end




    def setUpAnnoGraph(lffLines, rcsLines=nil, sdLines=nil, configString=nil)
      minCoeff = 0.01
      minReadCoverage = 4
      barArray = Array.new
      elementStrand = nil
      configHash = nil
      configNeeded = ! (configString.nil? or configString.empty?)
      if(configNeeded) then configHash = JSON.parse(CGI.unescape(configString)) end
      # Create bars from lff lines 1 per gene element
      lffLines.each_with_index { |line, ii|
        splitLine = line
        if(splitLine.size >= 10)
          elementName = splitLine[1]
          elementStrand = splitLine[7]
          elementScore = splitLine[9].to_f.abs
          attrs = Hash.new
          if(splitLine.size > 12)
            avps = splitLine[12].gsub(/\s/, '').split(/;/) # gsub here not really necessary and could add slowness
            avps.each { |avp|
              (aa,vv) = avp.split(/=/)
              attrs[aa] = vv
            }
            elementColor = attrs[@colorAttr]
            elementType = attrs[@typeAttr]
            if(attrs[@nameAttr] =~/^Exon/) then
              elementName = attrs[@nameAttr].gsub(/\D/,"")
            elsif(attrs[@nameAttr] !~ /\D/) then
              elementName = attrs[@nameAttr]
            else
              elementName = nil
            end
            elementOrder = attrs["Order"].to_i
          else
            $stderr.puts "ERROR? The gene model line has no AVPs at all??? Line & fields:\n#{line.inspect}\n#{splitLine.inspect}"
          end
          if(elementColor.nil?)
            elementColor = BRL::Genboree::GeneViewer::GeneElementsUtil::ELEM2COLOR[elementType]
          end
          # If no element color (direct or indirect via element type), go with black
          if(elementColor.nil? or elementColor !~ /#[a-f0-9]{6}/i)
            elementColor = "#000000"
          end
          sdValue = 0
          if(!sdLines.nil?)
            sdValue = sdLines[ii].split(/\t/)[9].to_f.abs
          end
          elementInclude = true
          if(configNeeded)
            configVal = configHash[BRL::Genboree::GeneViewer::GeneElementsUtil::JSONELEMCODES[elementType]]
            if(configVal[0] == 'n') then
              elementInclude = false
            elsif(!configVal.include?(elementOrder) and configVal[0]!='a')
              elementInclude = false
            end
          end
          if(elementInclude) then
            bar = BRL::Genboree::Graphics::Bar.new
            bar.score = elementScore
            bar.color = elementColor
            bar.type = elementType
            bar.name = elementName
            bar.stdev = sdValue
            #$stderr.puts "bs #{bar.score}"
            # For methylation if the coeff. is too low and the coverage is too low, mark as a special case to be dealt with while drawing
            if(@imgType == :methylation and bar.score <= minCoeff) then
              #rcValues = rcsLines[ii].split(/\t/)
              rcValues = rcsLines[ii]
              #$stderr.puts "bs #{bar.score} rc #{rcValues[9]}"
              if(rcValues[9].to_f < minReadCoverage)
                bar.score = -1
              end
            end
            barArray << bar
          end
        else
          $stderr.puts "ERROR? The gene model line not LFF. Probably request error (missing resource?) Line & fields:\n#{line.inspect}\n#{splitLine.inspect}"
        end
      }
      # Handle negative strand genes
      if(elementStrand == '-')
        barArray = barArray.reverse
      end
      # max. score for scaling
      maxScore = barArray.map{ |bb| bb.score }.max

      bd = BRL::Genboree::Graphics::BarGlyphDrawer.new(barArray)
      bc = BRL::Genboree::Graphics::BarGlyphConfig.new
      bc.maxScore=maxScore
      bc.xlabel = "Exon Number"
      bc.imageType = @imgType
      if(@imgType == :methylation) then
        bc.title = "Methylation Proportion"
        bc.minValue = 1
      else
        bc.title = "Read Density"
        bc.minValue = 10
      end
      pngBlob = bd.draw(bc)
      return pngBlob
    end

    def extractAnnoLines(annoName, scrTrack, roiTrack, aggFunction)
      
      roiTrackPath = BRL::Genboree::REST::Helpers::TrackApiUriHelper.new.extractPath(roiTrack)
      rsrcPath ="#{roiTrackPath}/annos?#{URI.parse(roiTrack).query}&format=lff&scoreTrack={scrTrack}&spanAggFunction=#{aggFunction}&nameFilter={name}&emptyScoreValue={esValue}"
      #@apiCaller.setRsrcPath("#{roiTrackPath}/annos?#{URI.parse(roiTrack).query}&format=lff&scoreTrack={scrTrack}&spanAggFunction=#{aggFunction}&nameFilter={name}&emptyScoreValue={esValue}")
      @apiCaller.setRsrcPath(rsrcPath)
      # Do internal request if enabled (in this case, if we've been given a Rack env hash to work from)
      @apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
      resp = @apiCaller.get(
      {
        :scrTrack => scrTrack,
        :name => annoName,
        :esValue => 0
      }
      )

      if(@apiCaller.succeeded?)
        if(@apiCaller.isInternalApiCall)
          # Then resp is some kind of I/O like thing that response to each()
          # Here, we want this as one big chunk
          #$stderr.debugPuts(__FILE__, __method__, "hqe","api chunking #{resp.class}")
          retVal = StringIO.new()
          resp.each { |chunk|
            #$stderr.debugPuts(__FILE__, __method__, "hqe","chunk #{chunk}")
            retVal << chunk
          }
          retVal = retVal.string
        else # not internal call, usual apiCaller operation
          # return the apiCaller respBody
          retVal = apiCaller.respBody
        end
        
      else
        $stderr.puts "ERROR: apiCaller to get LFF score data failed. ApiCaller response body:\n#{@apiCaller.respBody.inspect}"
        $stderr.puts @apiCaller.rsrcPath.inspect
        retVal = nil
      end
      return retVal
    end
  end
end ; end ; end # module BRL ; module Genboree ; module Graphics
