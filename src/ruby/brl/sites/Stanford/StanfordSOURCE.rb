#!/usr/bin/env ruby

# ##############################################################################
# REQUIRED LIBRARIES
# ##############################################################################
require 'mechanize'
require 'hpricot'
require 'cgi'

SubSection = Struct.new(:title, :content)

# Supports searching terms at Stanford SOURCE web site and extracting specified information from results.
class StanfordSOURCE
  attr_accessor :uriTemplate, :organism, :searchTerm, :searchType, :reqSection, :subSections

  # Constructor. Can override default organism and search type if provide arguments.
  def initialize(organism='Hs', searchType='Gene')
    @organism, @searchType = organism, searchType
    @searchTerm, @reqSection, @subSections = nil
    @uriTemplate = "http://smd.stanford.edu/cgi-bin/source/sourceResult?organism={organism}&option=Name&criteria={searchTerm}&choice={searchType}&.submit=Submit&.cgifields=choice"
  end

  # Do a search of a term against Stanford SOURCE.
  # In addtion to a search term, at least least 1 subSection (category of information) to extract the contents of.
  # Returns array of SubSection objects.
  def search(searchTerm=@searchTerm, subSections=@subSections, reqSection=@reqSection)
    raise "Error: you not provide a search term!" if(searchTerm.nil? or searchTerm.empty?)
    raise "Error: you haven't specified which subSections of the result table to extract!" if(subSections.nil? or subSections.empty?)
    urlStr = makeURI(searchTerm)                            # Make search URL by filling in fields of URI-Template
    agent = WWW::Mechanize.new()                            # Make a web agent
    resultPage = agent.get(urlStr)                          # Do search via 'get'
    retVal = verifyResultPage(resultPage, reqSection)       # Verify search results looks ok
    if(retVal != :SEARCH_FAILED)  # then search found something or other for the term
      selectedInfo = []
      if(retVal == :OK) # then got direct result page (just 1 hit)
        selectedInfo = parseResults(resultPage, subSections, selectedInfo)
      elsif(retVal == :MULTIPLE_RESULTS) # then got a list of results...get info from each one
        resultLinkElems = resultPage/"td[text()=#{searchTerm}]/../td/a"
        # Go through each link, get the indicated result page, and do regular verify/parse of that page
        resultLinkElems.each { |resultLinkElem|
          href = resultLinkElem[:href]
          if(href)
            subResultAgent = WWW::Mechanize.new()           # Make a web agent
            subResultPage = subResultAgent.get(href)        # Get result page
            verifyOk = verifyResultPage(subResultPage, reqSection)
            if(verifyOk == :OK) # then got direct result page
              selectedInfo = parseResults(resultPage, subSections, selectedInfo)
            end
          end
        }
      end
      retVal = selectedInfo
    end
    return retVal
  end

  # ############################################################################
  # HELPER METHODS:
  # ############################################################################
  # Construct a search URL from the URI Template by filling in parameter values.
  def makeURI(searchTerm=@searchTerm, searchType=@searchType, organism=@organism)
    retVal = @uriTemplate.dup
    retVal.gsub!(/\{organism\}/, CGI.escape(organism))
    retVal.gsub!(/\{searchType\}/, CGI.escape(searchType))
    retVal.gsub!(/\{searchTerm\}/, CGI.escape(searchTerm))
    return retVal
  end

  # Parse a Stanford SOURCE search result page, extract desired content,
  # and add it to array of currently selected info.
  def parseResults(resultPage, subSections, selectedInfo)
    # Get subsections of results (if present)
    subSections.each { |subSection|
      # Get text elements from subSection row
      subSectContentElems = resultPage/"//td[text()='#{subSection}']/../td//text()"
      subSectContentElems.each { |subSectContentElem|
        text = subSectContentElem.to_s
        next if(text =~ /^#{Regexp::quote(subSection)}/)    # skip the subsection name text elements
        selectedInfo << SubSection.new(subSection, text)    # add entries for subsection content text
      }
    }
    return selectedInfo
  end

  # Check that Stanford SOURCE search result page looks good.
  # Indicate if a direct result page, a multiple result page, a failed search page,
  # or if missing required section.
  def verifyResultPage(resultPage, reqSection=nil)
    retVal = :OK
    # Check for No Gene Name type message (i.e. search failed)
    badMsgElems = resultPage/"b[text()^='No'][text()*='was found matching']"
    if(badMsgElems.nil? or badMsgElems.empty?)
      # Maybe we have direct result or a page of links to multiple results?
      multipleResultsElem = resultPage/"font[text()*='were found matching your query']"
      unless(multipleResultsElem.nil? or multipleResultsElem.empty?) # then we have multiple results on this page
        retVal = :MULTIPLE_RESULTS
      else # just direct result (1 match)
        if(reqSection) # have we got a required section in results table?
          reqSectionTitleElem = resultPage/"td/[text()='#{reqSection}']"
          if(reqSectionTitleElem.nil? or reqSectionTitleElem.empty?)
            retVal = :NO_REQ_SECTION
          end
        end
      end
    else
      retVal = :SEARCH_FAILED
    end
    return retVal
  end
end
