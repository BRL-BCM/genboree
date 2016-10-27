require 'json'
require 'brl/util/util'
require 'brl/genboree/genboreeContext'
require 'brl/genboree/rest/apiCaller'

module BRL;module Genboree;module Pathways;
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

    def initialize(release='4')
      @release = release
      @genbConf = BRL::Genboree::GenboreeConfig.load
      suDbDbrc = BRL::Genboree::GenboreeUtil.getSuperuserDbrc()
      @dbrc = suDbDbrc
      @dbrc.user = @dbrc.user.dup.untaint
      @dbrc.password = @dbrc.password.dup.untaint
      @geneElements = Array.new
    end

    def getGeneElementsByClass
      elClasses = Hash.new(){|h, k| h[k] = Array.new}
      if(!@geneElements.empty?) then
        @geneElements.each{|element|
          elClasses[element.class] << element
        }
      end
      return elClasses
    end

    def renderGeneElementsAsJSON(geneName)
      fillGeneElements(geneName)
      jsonHash = Hash.new
      jsonHash["name"] = @geneName
      jsonHash["strand"] = @strand
      jsonHash["coords"] = @geneCoords
      elClasses = Hash.new(){|h, k| h[k] = Array.new}
      elArray = Array.new
      @geneElements.each_with_index{|element,ii|
        elClasses[element.class] << ii
        elArray << {"gene" => element.geneName,"name" =>  element.name,"type" => element.type,"order" => element.order,"className" => element.class ,"coords" => element.coords, "checked"=> true}
      }
      jsonHash["elDetails"] = elArray
      classArray = Array.new
      ELEMORDER.each{|cat|
        cgiCat = CGI.escape(cat)
        if(elClasses.has_key?(cgiCat)) then
          classArray << {"name" => cgiCat, "list" => elClasses[cgiCat], "showAll" => true, "showNone" => false,"color" => ELEM2COLOR[cat]}
        end
      }
      jsonHash["elClasses"] = classArray
      return jsonHash.to_json
    end

    def renderGeneElementsForUCSC(geneName)
       elLines = getGeneElementLines(geneName)
       if(!elLines.nil?) then
         elLines = getLineFieldsAndAttrs(elLines,["Name"])

         if(elLines[0][:strand] == '+')
           @geneCoords = "#{elLines[1][:coords].split(/\-/)[0]}-#{elLines[-1][:coords].split(/\-/)[1]}"
         else
           @geneCoords = "#{elLines[-1][:coords].split(/\-/)[0]}-#{elLines[1][:coords].split(/\-/)[1]}"
         end
          buff = StringIO.new
      buff<<"<div id=\"outerContainer\" class=\"extColor\" style=\"overflow:auto;height:100%;\">"
      buff<<"<div id=\"elementContainer\" class=\"extColor\" >"
      buff<<"<ul>"
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
        <input type="checkbox" style="vertical-align:bottom;" class="ucscCheckBox" onClick="checkSelectAll(this,'selectAll_ucsc');" value="#{ee[:coords]}" id="chk_#{ee["Name"]}" checked="true">
        #{ee["Name"].gsub(/_/,' ')}
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


    def getCheckboxHTML(elements, names, colors)
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

    def renderGeneElements(geneName)
      fillGeneElements(geneName)
      elClasses = getGeneElementsByClass()
      buff = StringIO.new
      buff<<"<div id=\"outerContainer\" class=\"extColor\" style=\"overflow:auto;height:100%;\">"
      buff<<"<div id=\"elementContainer\" class=\"extColor\" >"
      buff<<"<ul>"
      ELEMORDER.each{|cat| #Gives the right sort order P,5,E,I,3
        cgiCat = CGI.escape(cat)
        if(elClasses.has_key?(cgiCat)) # A gene may not have all classes of elements
          catColor = ELEM2COLOR[cat]
          buff<< <<-EOS
          <li>
          <div style="padding:5px; padding-left:10px; font:bold 11px verdana; display:table;">
          <div style="display:table-cell;padding-right:10px;">
          <input type="checkbox" value="#{cgiCat}" style="vertical-align:bottom;" id="selectAll_#{cgiCat}"
          EOS
          if(elClasses[cgiCat].length > 1) then
            buff << "onClick=\"toggleElementClassSelection(this.checked,'#{cgiCat}');\""
          end
          buff<< <<-EOS
          >
          &nbsp;#{cat}s
          </div>
          <div style=\"display:table-cell; vertical-align:middle;\">
          <div style="height:8px; width:8px; background-color:#{catColor};">&nbsp;</div>
          </div>
          </div>
          </li>
          EOS
          if(elClasses[cgiCat].length > 1) then
            spanId = "span_#{cgiCat}"
            tableId = "table_#{cgiCat}"
            textId = "text_#{cgiCat}"
            toggleText = "Choose #{cat}s"
            buff<< <<-EOS
            <div style="padding-left:30px;">
              <span id="#{spanId}" name="#{tableId}" class="advancedImgToggle" onclick="toggleAdvancedSettings('#{spanId}', '#{tableId}');" collapseState="collapsed">&nbsp;</span>
              <span id="#{textId}" name="#{textId}" class="advancedTextToggle" onclick="toggleAdvancedSettings('#{spanId}', '#{tableId}');resizeHeight(gnElWindow,10,'#outerContainer','#elementContainer');">#{CGI.escapeHTML(toggleText)}</span></div>
              <table id="#{tableId}" name="#{tableId}" class="advancedTable" style="display:none; width: 100%;">
              <tr><td class="advancedTableText" style="width: 100%">
            EOS
            elClasses[cgiCat].sort_by{|xx| xx.order.to_i}.each{|element|
            buff<< <<-EOS
            <li>
            <span style="padding-left:30px;font:11px verdana;">
            <input type="checkbox" style="vertical-align:bottom;" onClick="checkSelectAll(this,'selectAll_#{cgiCat}');" class="#{cgiCat}" value="#{element.name}" id="chk_#{element.name}">
            #{CGI.unescape(element.class)} #{element.order}
            </span>
            </li>
            EOS
          }
          buff << "</td></tr></table>"
            end
        end
      }
      buff<<"</ul>"
      buff<<"</div>"
      buff<<"</div>"
      return buff.string
    end


    def getElementAttrs(options)
      if(options[:type] == :gene) then
        getGeneElementAttrs(options)
      end
    end


def getLineFieldsAndAttrs(elementLines,attrs=nil)
  valArray = []
  doAttrs = !(attrs.nil? or attrs.empty?)
  elementLines.each{|lineArray|
    vals = Hash.new
    vals[:coords] = "#{lineArray[4]}:#{lineArray[5]}-#{lineArray[6]}"
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


def getAttrsForElements(elementLines,options)
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


def getGeneElementLines(geneName,scrTrack=nil)
  rc = @release
      if(rc.nil?) then rc = @genbConf.propTable["edaccReleaseCount"] end
      #TDroiTrack = @genbConf.propTable["eaRoiTrackPath_#{rc}"]
      roiTrack = "/REST/v1/grp/raghuram_group/db/datafreeze4/trk/GeneModel%3AGeneRefSeq"

      roiTrackPath = "http://#{@genbConf.eaRoiTrackHost}#{roiTrack}"
      scrTrackPath = roiTrackPath
      if(!scrTrack.nil?) then
        scrGrp = @genbConf.propTable["scoreTrackGroup_#{rc}"]
        scrDB = @genbConf.propTable["scoreTrackDB_#{rc}"]
        scrTrackPath = "http://genboree.org/REST/v1/grp/#{CGI.escape(scrGrp)}/db/#{CGI.escape(scrDB)}/trk/#{options[:scrTrack]}"
      end
      @apiCaller = BRL::Genboree::REST::ApiCaller.new("genboree.org",
      "#{roiTrack}/annos?format=lff&scoreTrack={scrTrackPath}&nameFilter={name}&emptyScoreValue={esValue}",
      @dbrc.user,
      @dbrc.password)



      @apiCallerSettings = {
        :name => geneName,
        :esValue => 0,
        :scrTrackPath => scrTrackPath
      }
      @apiCaller.get(@apiCallerSettings)
        if(@apiCaller.succeeded?) then
          elementLines = apiCaller.respBody.lines.to_a
          elementLines.each_index{|ii|
            elementLines[ii] = elementLines[ii].split(/\t/)

            if(elementLines[ii].length > 12) then
            attrs = Hash.new;
              avps = elementLines[ii][12].gsub(/\s/,'').split(/;/);
              avps.each { |avp| (aa,vv) = avp.split(/=/);attrs[aa] = vv
              }
              elementLines[ii][12] = attrs
            end
          }
          return elementLines
        else
          $stderr.puts "#{Time.now} apiCaller didn't succeed  #{@apiCallerSettings.inspect} #{@apiCaller.respBody}"
          return nil
        end
end

    def getGeneElementAttrs(options)
      elLines = getGeneElementLines(options[:geneName],options[:scrTrack])
      if(!elLines.nil?) then
        return getAttrsForElements(elLines,options)
      else
        return nil
      end
    end

    end

end;end;end
