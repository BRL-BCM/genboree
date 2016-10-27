require 'cgi'
require 'open-uri'
require 'brl/util/util'
require 'brl/genboree/genboreeContext'
require 'mechanize'

module BRL;module Genboree;module Pathways;

  class PathwayUtil
    Pathway = Struct.new(:name, :link, :keggId)
    Gene = Struct.new(:name,:keggId)
    # This function searches KEGG for the pathways in which a gene appears. The results are returned in a hierearchical fashion in a multi-level hash where the values at the lowest level are the pathways
    # For each pathway, the pathway name, its kegg id and the kegg link to the pathway are returned.The intermediate keys of the hash are the categories
    # See renderPathwayHash() below for example traversal code
    def self.findPathways(geneName)
      allPathways = nil
      unless(geneName.empty? or geneName.nil?)
        # We need a "browser". We lie to remote hosts so they don't prevent our "robot" programmatic browsing.
        agent = Mechanize.new()
        agent.user_agent_alias = 'Linux Firefox'
        agent.max_history = 10 # else infinite
        # Grab Kegg gene-search page contents
        # - use this link to look up pathways for a gene by name:
        page = agent.get("http://www.genome.jp/dbget-bin/www_bget?hsa:#{geneName}")
        # Root URL
        @baseURL = "#{page.uri.scheme}://#{page.uri.host}"
        # Try to get content we want; if no content, then probably a failed look up. Thus, we always have to be mindful of:
        # 1. Success pages with content we want
        # 2. Failure page (or pages if different types of failure) when info is missing, gene name is bad, etc.
        tdsWithPathways = page.search("//a[contains(@href, 'show_path')]/parent::*[contains(., 'PATH')]")
        success = !(tdsWithPathways.nil? or tdsWithPathways.empty?)
        if(success) # Found some pathways, extract them from Kegg's page
          allPathways = Hash.new { |hh, kk| hh[kk] = {} }
          td = tdsWithPathways.first # should only be 1, but if more, we'll take the first only
          tdHtml = td.inner_html.gsub(/\n/, ' ').gsub(/<br>|\]/, '')
          pathways = []
          # Extract each pathway found. We want the pathway name, id, link.
          tdHtml.scan(/(.+?)\[(PATH|[A-Z]+):\s*<a\s+href="([^"]+)"\s*>([^<]+)<\/a>/) { |matches|
            linkType = matches[1]
            next if(linkType != "PATH") # The regexp will match a few other things too, in an attempt not to miss anything and make debugging easy.
            # Go through categories and store in allPathways Hash.
            # - last category is the pathway name
            categories = matches[0].split(/;/).map{ |xx| xx.strip }
            numParentCateories = categories.size - 1
            currParentHash = allPathways
            numParentCateories.times { |ii|
              parentCategory = categories[ii]
              currParentHash[parentCategory] ||= {} # Create entry if not there yet
              currParentHash = currParentHash[parentCategory]
            }
            # Store the pathway name (last 'category')
            currParentHash[categories.last] = Pathway.new(categories.last, matches[2], matches[3])
          }
        end
      end
      return allPathways
    end

    # This function uses simple recursion to render the HTML for the
    # nested cateogries and their pathways which is then used by the pathway browser
    def self.renderPathwayHash(pathwayHash,geneName, nonLeafClass="", pathwayClass="", keggClass="")
      buff = "<ul class=\"#{nonLeafClass}\">\n"
      pathwayHash.keys.sort{|aa,bb| aa.downcase<=>bb.downcase}.each { |name|
        rec = pathwayHash[name]
        # If rec is a Hash, then this is a category
        if(rec.is_a?(Hash))
          # Open the list for this category
          buff << <<-EOS
          <li>
          <span class="#{nonLeafClass}">#{CGI.escapeHTML(name)} : </span>
          EOS
          # Display the children in this category (will return a <ul>)
          buff << renderPathwayHash(rec,geneName,nonLeafClass, pathwayClass, keggClass)
          # Close list for this category
          buff << <<-EOS
          </li>
          EOS
          # Else if rec is a Pathway then we want to show a pathway link
        else # a Pathway
          # Kegg link:
          keggLink = "#{@baseURL}#{rec.link}"
          # Pathway Space wrapper link
          # - we wrap Kegg's URL for the actual pathway as an argument to our "augmentation" page
          #wrapperLink = "/genboree/pathwayWrapper.rhtml?geneName=#{CGI.escape(@geneName)}&keggURL=#{CGI.escape(keggLink)}"
          # Make list entry for this pathway item
          buff << <<-EOS
          <li style="width: 100%; display: table-row;">
          <div style="display: table-cell; width: 100%;">
          <span class="#{pathwayClass}">
          &quot;#{CGI.escapeHTML(rec.name)}&quot;
          <span class="#{keggClass}">(Kegg Pathway Id: #{CGI.escapeHTML(rec.keggId)})</span>
          </span></div>
          <div style="display: table-cell;">
          <input type='button' value='Pick genes' onClick='showGeneDialog("#{CGI.escape(rec.name)}","#{CGI.escape(geneName)}","#{CGI.escape(keggLink)}")' >
          <input type='hidden' class='geneList' id="#{CGI.escape(rec.name)}">
          </div>
          </li>
          EOS
        end
      }
      buff << '</ul>'

      return buff
    end


    # Returns a collection of gene names (and their kegg Ids) present in a pathway. The keggURL returned in findPathways needs to be prepended with a base url before it can be used here.
    def self.findGenesInPathway(keggURL)
      keggGenes  = Array.new
      unless(keggURL.empty? or keggURL.nil?)
        # We need a "browser". We lie to remote hosts so they don't prevent our "robot" programmatic browsing.
        agent = Mechanize.new()
        agent.user_agent_alias = 'Linux Firefox'
        agent.max_history = 10 # else infinite
        # Grab Kegg pathway page
        page = agent.get(keggURL)
        # Root URL
        baseURL = "#{page.uri.scheme}://#{page.uri.host}"
        # Nokogiri html document object to make augmentation easy.
        # - you will see a lot of xpath and/or CSS style searches to select relevant tags or attributes; very powerful
        doc = page.parser
        areaElems = doc.search("//map[@name='mapdata']/area")
        areaElems.each { |elem|
          href = elem['href']
          title = elem['title']
          # Does this look like a gene-name <area>? If not, skip
          if(href and title)
            if(href =~ %r{\?hsa:\d+}) # then looks like a gene node in the image
              # Try to accumulate all the keggIds and matching gene names from the title attribute
              title.scan(/(\d+)\s*\(([^\)]+)\)/) { |geneInfoMatch| # Then title also looks like it is a [possible CSV list of ) '12345 (geneName)'
                keggGeneId = geneInfoMatch[0]
                geneName = geneInfoMatch[1]
                keggGenes << Gene.new(geneName,keggGeneId)
              }
            end
          end
        }
      end
      return keggGenes
    end

    # This function retrieves the pathway diagram for a KEGG pathway and modifies it in the following ways:
    # 1. All image elements (boxes) corresponding to a gene are overlaid with a transparent image of the same dimensions.
    # This allows for much greater flexibility in interactions with the pathway image as compared to the original KEGG area map.
    # 2. Each overlaid image is assigned a class (imgClass) so that the resulting image can be processed easily using js:document.getElementsByClassName()
    # The class names can also be changed on the fly for visual effects.
    # 3. All overlaid images are assigned an id of the form (imgDivPrefix{number}) for convenience.
    # 4. The original image and these overlaid images are wrapped within a imgDiv element and the HTML as a whole is wrapped within the containerDiv element.
    # 5. The onClick event for each overlaid image can be supplied as a string

    def self.getWrappedSamplePathwayImage(pathwayName,keggURL,imgClass="colorable imgDiv",imgDivPrefix="imgDiv",onClickString="")
      success = false
      unless(pathwayName.empty? or keggURL.empty?)
        # We need a "browser". We lie to remote hosts so they don't prevent our "robot" programmatic browsing.
        agent = Mechanize.new()
        agent.user_agent_alias = 'Linux Firefox'
        agent.max_history = 10 # else infinite
        # Grab Kegg pathway page
        page = agent.get(keggURL)
        page.encoding = nil # To stop nokogiri from &nbsp; -> \240 (and similar)
        # Root URL
        baseURL = "#{page.uri.scheme}://#{page.uri.host}"
        # Nokogiri html document object to make augmentation easy.
        # - you will see a lot of xpath and/or CSS style searches to select relevant tags or attributes; very powerful
        doc = page.parser
        # ------------------------------------------------------------------
        # Changes to Links on Page
        # ------------------------------------------------------------------
        # First, FIX all relative href and src attribute values for NON <area> tags
        # - these are non-pathway hotspots relative links to suff at Kegg
        # - but we're not at Kegg, so need to make ABSOLUTE links, so they will work
        nonAreaElems = doc.search("//*[@href or @src or @action][not(parent::map)]")
        nonAreaElems.each { |elem|
          # href
          href = elem['href']
          if(href and href !~ %r{[^:]+://[^/]+})  # We'll avoid editing links with protocol directly or within a void(window.open())
            # Replace the first / with http://host.com/. This should handle the simple cases of '/relative/link' and 'void(window.open("/rel/link"))'
            elem['href'] = elem['href'].sub(/\//, "#{baseURL}/")
          end
          # src
          src = elem['src']
          if(src and src !~ %r{[^:]+://[^/]+})  # We'll avoid editing links with protocol directly or within a void(window.open())
            # Replace the first / with http://host.com/. This should handle the simple cases of '/relative/link' and 'void(window.open("/rel/link"))'
            elem['src'] = elem['src'].sub(/\//, "#{baseURL}/")
          end
          # action
          src = elem['action']
          if(src and src !~ %r{[^:]+://[^/]+})  # We'll avoid editing links with protocol directly or within a void(window.open())
            # Replace the first / with http://host.com/. This should handle the simple cases of '/relative/link' and 'void(window.open("/rel/link"))'
            elem['action'] = elem['action'].sub(/\//, "#{baseURL}/")
          end
        }

        # Second, FIX all relative hrefs of <area> tags NOT in the <map> for the image.
        # - WTF is a is an area tag not in a map? well in this case it's:
        #   1. being super conservative, but more it is:
        #   2. dealing with any images and <map> tags for things OTHER than the pathway image
        areaElems = doc.search("//map[not(@name='mapdata')]/area")
        areaElems.each { |elem|
          # href
          href = elem['href']
          if(href and href !~ %r{[^:]+://[^/]+})  # We'll avoid editing links with protocol directly or within a void(window.open())
            # Replace the first / with http://host.com/. This should handle the simple cases of '/relative/link' and 'void(window.open("/rel/link"))'
            elem['href'] = elem['href'].sub(/\//, "#{baseURL}/")
          end
        }

        # Enclose the main image in a div of our creation
        imgElem = doc.search("//img[(@usemap='#mapdata')]")[0]

        imgDivNode = Nokogiri::XML::Node.new('div',doc)
        imgDivNode['id'] = imgDivPrefix
        imgDivNode['style'] = 'position:relative; width:100%;height:100%;'
        imgElem.parent.add_child(imgDivNode)
        imgDivNode.add_child(imgElem)

        # Third, MAKE LINK-BACKS to Genboree's Genome Space
        # - CHANGE the href's in <area> tags in the <map> for the image to point to a Genboree search using indicated gene name
        # - actually, make the href pop up a little dialog where the user can choose to go back to Genboree space OR follow original Kegg link!
        areaElems = doc.search("//map[@name='mapdata']/area")
        divCount = 0;
        areaElems.each { |elem|
          href = elem['href']
          title = elem['title']
          # Does this look like a gene-name <area>? If not, skip
          if(href and title)
            
            if(href =~ %r{\?KO\d+} or href =~ %r{\?ko\d+}) # then looks like a gene node in the image
            
              keggGeneIds = []
              geneNames = []
              title.scan(/(\d+):\s*([^\)]+)/) { |geneInfoMatch| # Then title also looks like it is a [possible CSV list of ) '12345 (geneName)'
                keggGeneIds << geneInfoMatch[0]
                geneNames << geneInfoMatch[1]
              }
              
              # Clear out the href, we're going to use onclick only.
              elem.delete('href')
              # Add onClick
              keggGeneIdsStr = keggGeneIds.map{ |xx| "'#{xx.strip}'" }.join(',')
              geneNamesStr = geneNames.map{ |xx| "'#{xx.strip}'" }.join(',')
              #         elem['onclick'] = "showLinkBacks( event, [#{keggGeneIdsStr}], [#{geneNamesStr}]) ;"
              elem['style'] = "cursor: pointer ;"

              # For each gene area create a div that covers it
              imgNode = Nokogiri::XML::Node.new('img',doc)
              coords = elem['coords'].split(/,/)
              imgNode['style'] = "position:absolute;top:#{coords[1]}px;left:#{coords[0]}px;height:#{coords[3].to_i-coords[1].to_i}px;width:#{coords[2].to_i-coords[0].to_i}px;cursor: pointer ;"
              imgNode['class'] = imgClass
              imgNode['id'] = "#{imgDivPrefix}#{divCount}"
              imgNode['name'] = geneNamesStr.gsub(/'/,"")
              imgNode['onclick'] = onClickString unless(onClickString.nil? or onClickString.empty?)
              imgNode['src'] = "/images/empty.png"
              imgDivNode.add_child(imgNode)
              divCount += 1


            else # some other kind of <area> tag link...need to fix to have baseUri
              if(href !~ %r{[^:]+://[^/]+})  # We'll avoid editing links with protocol directly or within a void(window.open())
                # Replace the first / with http://host.com/. This should handle the simple cases of '/relative/link' and 'void(window.open("/rel/link"))'
                elem['href'] = elem['href'].sub(/\//, "#{baseURL}/")
              end
            end
          end
        }

        # ------------------------------------------------------------------
        # CORE PAGE MODIFICATION
        # - do this after "fixing" the links above, so we don't end up
        #   modifying our own inserted links
        # ------------------------------------------------------------------
        # Change page title
        titleElems = doc.search("//title")
        unless(titleElems.empty?)
          titleElems.first.inner_html = "#{titleElems.first.inner_html} [Pathway Space wrapped by Genboree]"
        end
        # Fixup Help button animation
        helpElems = doc.search("//img[@name='help']")
        unless(helpElems.empty?)
          helpElem = helpElems.first
          helpElem.each { |attr, val| if(attr =~ /^onmouse/) then helpElem.delete(attr) ; end }
        end

        # wrap in top level div to make positioning in window easier
        bodyElem = doc.search("//body")[0]
        containerDivNode = Nokogiri::XML::Node.new('div',doc)
        containerDivNode['id'] = 'containerDiv'
        containerDivNode['style'] = "width:100%;height:100%;overflow:auto; "
        bodyElem.children.each{|child|
          containerDivNode.add_child(child)
        }
        bodyElem.add_child(containerDivNode)
        success = true
      end
      nih = nil
      if(success)
        nih = doc.inner_html.dup
      end
      return nih
    end


    def self.getWrappedPathwayImage(pathwayName,keggURL,imgClass="colorable imgDiv",imgDivPrefix="imgDiv",onClickString="")
      success = false
      unless(pathwayName.empty? or keggURL.empty?)
        # We need a "browser". We lie to remote hosts so they don't prevent our "robot" programmatic browsing.
        agent = Mechanize.new()
        agent.user_agent_alias = 'Linux Firefox'
        agent.max_history = 10 # else infinite
        # Grab Kegg pathway page
        page = agent.get(keggURL)
        page.encoding = nil # To stop nokogiri from &nbsp; -> \240 (and similar)
        # Root URL
        baseURL = "#{page.uri.scheme}://#{page.uri.host}"
        # Nokogiri html document object to make augmentation easy.
        # - you will see a lot of xpath and/or CSS style searches to select relevant tags or attributes; very powerful
        doc = page.parser
        # ------------------------------------------------------------------
        # Changes to Links on Page
        # ------------------------------------------------------------------
        # First, FIX all relative href and src attribute values for NON <area> tags
        # - these are non-pathway hotspots relative links to suff at Kegg
        # - but we're not at Kegg, so need to make ABSOLUTE links, so they will work
        nonAreaElems = doc.search("//*[@href or @src or @action][not(parent::map)]")
        nonAreaElems.each { |elem|
          # href
          href = elem['href']
          if(href and href !~ %r{[^:]+://[^/]+})  # We'll avoid editing links with protocol directly or within a void(window.open())
            # Replace the first / with http://host.com/. This should handle the simple cases of '/relative/link' and 'void(window.open("/rel/link"))'
            elem['href'] = elem['href'].sub(/\//, "#{baseURL}/")
          end
          # src
          src = elem['src']
          if(src and src !~ %r{[^:]+://[^/]+})  # We'll avoid editing links with protocol directly or within a void(window.open())
            # Replace the first / with http://host.com/. This should handle the simple cases of '/relative/link' and 'void(window.open("/rel/link"))'
            elem['src'] = elem['src'].sub(/\//, "#{baseURL}/")
          end
          # action
          src = elem['action']
          if(src and src !~ %r{[^:]+://[^/]+})  # We'll avoid editing links with protocol directly or within a void(window.open())
            # Replace the first / with http://host.com/. This should handle the simple cases of '/relative/link' and 'void(window.open("/rel/link"))'
            elem['action'] = elem['action'].sub(/\//, "#{baseURL}/")
          end
        }

        # Second, FIX all relative hrefs of <area> tags NOT in the <map> for the image.
        # - WTF is a is an area tag not in a map? well in this case it's:
        #   1. being super conservative, but more it is:
        #   2. dealing with any images and <map> tags for things OTHER than the pathway image
        areaElems = doc.search("//map[not(@name='mapdata')]/area")
        areaElems.each { |elem|
          # href
          href = elem['href']
          if(href and href !~ %r{[^:]+://[^/]+})  # We'll avoid editing links with protocol directly or within a void(window.open())
            # Replace the first / with http://host.com/. This should handle the simple cases of '/relative/link' and 'void(window.open("/rel/link"))'
            elem['href'] = elem['href'].sub(/\//, "#{baseURL}/")
          end
        }

        # Enclose the main image in a div of our creation
        imgElem = doc.search("//img[(@usemap='#mapdata')]")[0]

        imgDivNode = Nokogiri::XML::Node.new('div',doc)
        imgDivNode['id'] = imgDivPrefix
        imgDivNode['style'] = 'position:relative; width:100%;height:100%;'
        imgElem.parent.add_child(imgDivNode)
        imgDivNode.add_child(imgElem)

        # Third, MAKE LINK-BACKS to Genboree's Genome Space
        # - CHANGE the href's in <area> tags in the <map> for the image to point to a Genboree search using indicated gene name
        # - actually, make the href pop up a little dialog where the user can choose to go back to Genboree space OR follow original Kegg link!
        areaElems = doc.search("//map[@name='mapdata']/area")
        divCount = 0;
        areaElems.each { |elem|
          href = elem['href']
          title = elem['title']
          # Does this look like a gene-name <area>? If not, skip
          if(href and title)
            if(href =~ %r{\?hsa:\d+}) # then looks like a gene node in the image
              # Try to accumulate all the keggIds and matching gene names from the title attribute
              keggGeneIds = []
              geneNames = []
              title.scan(/(\d+)\s*\(([^\)]+)\)/) { |geneInfoMatch| # Then title also looks like it is a [possible CSV list of ) '12345 (geneName)'
                keggGeneIds << geneInfoMatch[0]
                geneNames << geneInfoMatch[1]
              }
              # Clear out the href, we're going to use onclick only.
              elem.delete('href')
              # Add onClick
              keggGeneIdsStr = keggGeneIds.map{ |xx| "'#{xx.strip}'" }.join(',')
              geneNamesStr = geneNames.map{ |xx| "'#{xx.strip}'" }.join(',')
              #         elem['onclick'] = "showLinkBacks( event, [#{keggGeneIdsStr}], [#{geneNamesStr}]) ;"
              elem['style'] = "cursor: pointer ;"

              # For each gene area create a div that covers it
              imgNode = Nokogiri::XML::Node.new('img',doc)
              coords = elem['coords'].split(/,/)
              imgNode['style'] = "position:absolute;top:#{coords[1]}px;left:#{coords[0]}px;height:#{coords[3].to_i-coords[1].to_i}px;width:#{coords[2].to_i-coords[0].to_i}px;cursor: pointer ;"
              imgNode['class'] = imgClass
              imgNode['id'] = "#{imgDivPrefix}#{divCount}"
              imgNode['name'] = geneNamesStr.gsub(/'/,"")
              imgNode['onclick'] = onClickString unless(onClickString.nil? or onClickString.empty?)
              imgNode['src'] = "/images/empty.png"
              imgDivNode.add_child(imgNode)
              divCount += 1


            else # some other kind of <area> tag link...need to fix to have baseUri
              if(href !~ %r{[^:]+://[^/]+})  # We'll avoid editing links with protocol directly or within a void(window.open())
                # Replace the first / with http://host.com/. This should handle the simple cases of '/relative/link' and 'void(window.open("/rel/link"))'
                elem['href'] = elem['href'].sub(/\//, "#{baseURL}/")
              end
            end
          end
        }

        # ------------------------------------------------------------------
        # CORE PAGE MODIFICATION
        # - do this after "fixing" the links above, so we don't end up
        #   modifying our own inserted links
        # ------------------------------------------------------------------
        # Change page title
        titleElems = doc.search("//title")
        unless(titleElems.empty?)
          titleElems.first.inner_html = "#{titleElems.first.inner_html} [Pathway Space wrapped by Genboree]"
        end

        # Fixup Help button animation
        helpElems = doc.search("//img[@name='help']")
        unless(helpElems.empty?)
          helpElem = helpElems.first
          helpElem.each { |attr, val| if(attr =~ /^onmouse/) then helpElem.delete(attr) ; end }
        end

        # wrap in top level div to make positioning in window easier
        bodyElem = doc.search("//body")[0]
        containerDivNode = Nokogiri::XML::Node.new('div',doc)
        containerDivNode['id'] = 'containerDiv'
        containerDivNode['style'] = "width:100%;height:100%;overflow:auto; "
        bodyElem.children.each{|child|
          containerDivNode.add_child(child)
        }
        bodyElem.add_child(containerDivNode)
        success = true
      end
      nih = nil
      if(success)
        nih = doc.inner_html.dup
      end
      return nih
    end



  end

end
end
end
