require 'json'
require 'brl/util/util'
require 'brl/genboree/genboreeContext'
require 'brl/genboree/rest/apiCaller'
require "brl/genboree/rest/helpers/trackApiUriHelper"

module BRL;module Genboree;module GeneViewer;
  class GeneElementsUtil
    attr_accessor :genbConf
    attr_accessor :dbrc
    attr_accessor :apiCaller

    attr_accessor :release
    attr_accessor :geneName
    attr_accessor :strand
    attr_accessor :geneCoords
    attr_accessor :geneElements
    GeneElement = Struct.new(:geneName, :name, :class, :order, :type, :coords)

    ELEM2COLOR =
    {
      "Promoter" => "#00d500",
      "5'UTR" =>     "#ffaa00",
      "Exon" =>     "#d50000",
      "Intron" =>   "#0000c0",
      "3'UTR" =>     "#ffaa00"
    }

    JSONELEMCODES =
    {
      "Exon" => "e",
      "Intron" => "i",
      "Promoter" => "p",
      "5'UTR" => "5",
      "3'UTR" => "3"
    }

    ELEMORDER = ["Promoter", "5'UTR", "Exon", "Intron", "3'UTR"]

    def self.getCredentials
      @genbConf = BRL::Genboree::GenboreeConfig.load()
      @dbrc = BRL::Genboree::GenboreeUtil.getSuperuserDbrc()
      @dbrc.user = @dbrc.user.dup.untaint
      @dbrc.password = @dbrc.password.dup.untaint
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "#{@dbrc.user} #{@dbrc.password}")
    end


    # Used to produce HTML when a user wants to see gene elements in ucsc
    def self.renderGeneElementsForUCSC(geneName)
      self.getCredentials
      elLines = getGeneElementLines(@genbConf.eaRoiTrackHost,geneName, @genbConf.eaRoiTrackPath)
      if(!elLines.nil?) then
        # get strand coords and the name attr
        elLines = getLineFieldsAndAttrs(elLines,["name"])
        # get coords of the gene in right orientation
        if(elLines[0][:strand] == '+')
          @geneCoords = "#{elLines[1][:coords].split(/\-/)[0]}-#{elLines[-1][:coords].split(/\-/)[1]}"
        else
          @geneCoords = "#{elLines[-1][:coords].split(/\-/)[0]}-#{elLines[1][:coords].split(/\-/)[1]}"
        end
        buff = StringIO.new
        buff<<"<div id=\"outerContainer\" class=\"extColor\" style=\"overflow:auto;height:100%;\">"
        buff<<"<div id=\"elementContainer\" class=\"extColor\" >"
        buff<<"<ul>"

        # the name attr value of a gene element is used as its display  name with underscores replaced by spaces. So the name can bw
        # {elementName}_{elementOrder} or {elementName}
        # result HTML has one line per element wiht a checkbox and element name shown.
        buff<< <<-EOS
        <li>
        <span style="padding:5px; padding-left:10px; font:11px verdana;">
        <input type="checkbox" value="#{@geneCoords}" style="vertical-align:bottom;" id="selectAll_ucsc" onClick="toggleElementClassSelection(this.checked,'ucscCheckBox');" checked="true"> All</span>
        </li>
        EOS
        elLines.each{|ee|
          buff<< <<-EOS
          <li>
          <span style="padding-left:30px;font:11px verdana;">
          <input type="checkbox" style="vertical-align:bottom;" class="ucscCheckBox" onClick="checkSelectAll(this,'selectAll_ucsc');" value="#{ee[:coords]}" id="chk_#{ee["name"]}" checked="true">
          #{ee["name"].gsub(/_/,' ')}
          </span>
          </li>
          EOS
        }
      else
        return nil
      end

      buff<<"</ul>"
      buff<<"</div>"
      buff<<"</div>"
      return buff.string
    end


    def self.getCheckboxHTML(elements, names, colors)
      buff = StringIO.new
      buff<<"<div id=\"outerContainer\" class=\"extColor\" style=\"overflow:auto;height:100%;\">"
      buff<<"<div id=\"elementContainer\" class=\"extColor\" >"
      buff<<"<ul>"
      elements.each{|ee|
        cgielm = CGI.escape(ee)
        if(names[ee].length > 0) then
          buff<< <<-EOS
          <li>
          <div style="padding:5px; padding-left:10px; font:bold 11px verdana; display:table;">
          <div style="display:table-cell;padding-right:10px;">
          <input type="checkbox" value="#{cgielm}" style="vertical-align:bottom;" id="selectAll_#{cgielm}"
          EOS
          if(names[ee].length > 1) then
            buff << "onClick=\"toggleElementClassSelection(this.checked,'#{cgielm}');\""
          end
          buff<< <<-EOS
          >
          &nbsp;#{ee}s
          </div>
          <div style=\"display:table-cell; vertical-align:middle;\">
          <div style="height:8px; width:8px; background-color:#{colors[ee]};">&nbsp;</div>
          </div>
          </div>
          </li>
          EOS
          if(names[ee].length > 1) then
            spanId = "span_#{cgielm}"
            tableId = "table_#{cgielm}"
            textId = "text_#{cgielm}"
            toggleText = "Choose #{ee}s"
            buff<< <<-EOS
            <div style="padding-left:30px;">
            <span id="#{spanId}" name="#{tableId}" class="advancedImgToggle" onclick="toggleAdvancedSettings('#{spanId}', '#{tableId}');" collapseState="collapsed">&nbsp;</span>
            <span id="#{textId}" name="#{textId}" class="advancedTextToggle" onclick="toggleAdvancedSettings('#{spanId}', '#{tableId}');resizeHeight(gnElWindow,10,'#outerContainer','#elementContainer');">#{CGI.escapeHTML(toggleText)}</span></div>
            <table id="#{tableId}" name="#{tableId}" class="advancedTable" style="display:none; width: 100%;">
            <tr><td class="advancedTableText" style="width: 100%">
            EOS
            names[ee].each{|element|
              buff<< <<-EOS
              <li>
              <span style="padding-left:30px;font:11px verdana;">
              <input type="checkbox" style="vertical-align:bottom;" onClick="checkSelectAll(this,'selectAll_#{cgielm}');" class="#{cgielm}" value="#{element}" id="chk_#{element}">
              #{element.gsub(/_/,' ')}
              </span>
              </li>
              EOS
            }
          end
          buff << "</td></tr></table>"
        end
      }
      buff<<"</ul>"
      buff<<"</div>"
      buff<<"</div>"
      return buff.string
    end


    # process an array of lff lines to get certain fields and avp values. The list of desired avps is
    # specified as an array.Field names returned are :coords and :strand. Any attr value can be present in the array
    # result is an array of hashes where each hash has keys :strand,:coords and any attr values that matched for that line

    def self.getLineFieldsAndAttrs(elementLines,attrs=nil)
      valArray = []
      doAttrs = !(attrs.nil? or attrs.empty?)
      elementLines.each{|lineArray|
        vals = Hash.new
        vals[:coords] = "#{lineArray[4]}:#{lineArray[5]}-#{lineArray[6]}"  #chr:start-stop
        vals[:strand] = lineArray[7]
        if(doAttrs and lineArray.length > 12) then
          attrs.each{|aa|
            vals[aa] = lineArray[12][aa]
          }
        end
        valArray << vals
      }
      if(!valArray.empty? and valArray[0][:strand] == '-') then valArray.reverse! end
      return valArray
    end


    def self.getAttrsForElements(elementLines,options)
      # Get strand and coords for entire gene first
      options[:elements].each_key{|ee|
        options[:elements][ee] = []
      }
      elementLines.each{|lineArray|
        attrs = lineArray[12]
        if(!attrs.nil?) then
          if(options[:elements].has_key?(attrs[options[:attrName]])) then
            vals = []
            options[:getAttrs].each{|aa| vals << attrs[aa]}
            options[:elements][attrs[options[:attrName]]] << vals
          end
        end
      }
      return options[:elements]
    end



    def self.getGeneElementLines(roiHost, geneName, roiTrackPath, scrTrackPath=nil)
      roiUri = "http://#{roiHost}#{roiTrackPath}"
      if(scrTrackPath.nil?) then scrTrackPath = roiUri end
      self.getCredentials
      trkHelper = BRL::Genboree::REST::Helpers::TrackApiUriHelper.new("")

      roiPrefix = trkHelper.extractPath(roiUri)
      apiCaller = BRL::Genboree::REST::ApiCaller.new(roiHost,
      "#{roiPrefix}/annos?#{URI.parse(roiUri).query}&format=lff&scoreTrack={scrTrackPath}&&spanAggFunction=avgByLength&nameFilter={name}&emptyScoreValue={esValue}",
      @dbrc.user,
      @dbrc.password)
      
      apiCallerSettings = {
        :name => geneName,
        :esValue => 0,
        :scrTrackPath => scrTrackPath
      }
      apiCaller.get(apiCallerSettings)
      if(apiCaller.succeeded?) then
        elementLines = apiCaller.respBody.lines.to_a
        elementLines.each_index{|ii|
          elementLines[ii] = elementLines[ii].split(/\t/)
          # if llf line has avps, stuff them into a hash
          if(elementLines[ii].length > 12) then
            attrs = Hash.new;
            avps = elementLines[ii][12].gsub(/\s/,'').split(/;/);
            avps.each { |avp| (aa,vv) = avp.split(/=/);attrs[aa.downcase] = vv
            }
            #replace array element with hash
            elementLines[ii][12] = attrs
          end
        }
        return elementLines
      else
        $stderr.puts "#{Time.now} apiCaller didn't succeed  #{apiCallerSettings.inspect} #{apiCaller.respBody}"
        return nil
      end
    end

    def self.getGeneElementAttrs(options)
      self.getCredentials
      elLines = getGeneElementLines(options[:roiHost], options[:geneName],options[:roiTrack],options[:scrTrack])
      if(!elLines.nil?) then
        return getAttrsForElements(elLines,options)
      else
        return nil
      end
    end
  end
end;end;end
