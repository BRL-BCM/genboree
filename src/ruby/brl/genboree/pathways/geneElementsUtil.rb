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

    def initialize(release='3')
      @release = release
      @genbConf = BRL::Genboree::GenboreeConfig.load
      suDbDbrc = BRL::Genboree::GenboreeUtil.getSuperuserDbrc()
      @dbrc = suDbDbrc
      @dbrc.user = @dbrc.user.dup.untaint
      @dbrc.password = @dbrc.password.dup.untaint
      @apiCaller = BRL::Genboree::REST::ApiCaller.new(
      "genboree.org",
      "#{@genbConf.propTable["eaRoiTrackPath_#{@release}"]}/annos?format=lff&scoreTrack={scrTrack}&nameFilter={name}&emptyScoreValue={esValue}",
      @dbrc.user,
      @dbrc.password)
      @apiCallerSettings = {
        :esValue => 0
      }
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
      fillGeneElements(geneName)
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
      @geneElements.each{|element|
        buff<< <<-EOS
        <li>
        <span style="padding-left:30px;font:11px verdana;">
        <input type="checkbox" style="vertical-align:bottom;" class="ucscCheckBox" onClick="checkSelectAll(this,'selectAll_ucsc');" value="#{CGI.unescape(element.coords)}" id="chk_#{element.name}" checked="true">
        #{CGI.unescape(element.class)} #{element.order}
        </span>
        </li>
        EOS
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

    def getGeneElements(geneName, scrTrack=nil)
      @geneName = geneName
      if(!@geneName.nil?) then
        @apiCallerSettings[:name] = geneName
        scrGrp = @genbConf.propTable["scoreTrackGroup_#{@release}"]
        scrDB = @genbConf.propTable["scoreTrackDB_#{@release}"]
        if(scrTrack.nil?)
          scrTrack = "http://#{@genbConf.eaRoiTrackHost}#{@genbConf.propTable["eaRoiTrackPath_#{@release}"]}"
        else
          scrTrack = "http://genboree.org/REST/v1/grp/#{CGI.escape(scrGrp)}/db/#{CGI.escape(scrDB)}/trk/#{scrTrack}"
        end

        @apiCallerSettings[:scrTrack] = scrTrack
        @apiCaller.get(@apiCallerSettings)
        if(@apiCaller.succeeded?) then
          return @apiCaller.respBody
        else
          $stderr.puts "#{Time.now} apiCaller didn't succeed  #{@apiCallerSettings.inspect} #{@apiCaller.respBody}"
          return nil
        end
      end
      return nil
    end


      def fillGeneElements(geneName)
        apiCallResult = getGeneElements(geneName)
        if(! (apiCallResult.nil?)) then
          elementLines = apiCaller.respBody.lines.to_a
          elementLines.each_index{|ii|
            elementLines[ii] = elementLines[ii].split(/\t/)
          }
          # Get strand and coords for entire gene first
          @strand = elementLines[0][7]
          if(@strand == '+') then  #first line is promoter
            @geneCoords = "#{elementLines[1][4]}:#{elementLines[1][5]}-#{elementLines[-1][6]}"
          else
            elementLines.reverse!
            @geneCoords = "#{elementLines[1][4]}:#{elementLines[-1][5]}-#{elementLines[1][6]}"
          end
          elementLines.each{|lineArray|
            if(lineArray.length > 12) then
              elCoords = "#{lineArray[4]}:#{lineArray[5]}-#{lineArray[6]}"
              attrs = Hash.new;
              avps = lineArray[12].gsub(/\s/,'').split(/;/);
              avps.each { |avp| (aa,vv) = avp.split(/=/);attrs[aa] = vv
              }
              type = attrs["Type"]
              order = ""
              if(attrs.has_key?("Name")) then # it's an exon so name=order
                order = attrs["Name"]
                elClass = "Exon"
                name = "#{elClass} #{order}"
              elsif(attrs.has_key?("Order"))
                order = attrs["Order"]
                elClass = "#{type}"
                name = "#{elClass} #{order}"
              else
                elClass = type
                name = elClass
              end
              @geneElements << GeneElement.new(geneName,CGI.escape(name), CGI.escape(elClass),order,CGI.escape(type),CGI.escape(elCoords))
            else
              $stderr.puts "ERROR? The gene model line has no AVPs at all??? Line & fields:\n#{lineArray.inspect}"
            end
          }
        end
      end
    end

end;end;end
