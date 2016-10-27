require "json"
require "net/http"
require "uri"
require "pp"
require "cgi"

##
# Definitions for all the Redmine specific utility methods to grab the main
# content for this website from the Redmine installation via API calls.
class GenboreeRedmine
  ##
  # Given the Redmine response, format the structured text as a hash.  This
  # implementation is basic, but used in the format of the Image rotators,
  # Events pages, News pages, and Publications.
  # +text+:
  #   The structured text directly from a Redmine Wiki page.
  #
  # +return+
  #   The Array of Hashes created by reading the <attr>: <value lines into an
  #   Array of Hashes with the AVPs.
=begin
  def self.transform(page, text)
    text = GenboreeRedmine.cleanRedmineWikiText(text)
    objects = []
    #$stderr.puts "#{__method__} => page: #{page.inspect} ; text:\n\n#{text}\n\n"
    text.split(/\r?\n\s*\r?\n/).each{ |group|
      item = {}
      group.lines.each{ |line|
        if(line =~ /(\w+):\s*(\S.*)/)
          item[$1] = $2.chomp
        elsif(line =~ /^\s*\{\{fnlist\}\}\s*$/)
          # No-op
          # Skip this tag which Redmine adds to indicate "List any page-attached files here"
        else
          #commenting out this line to avoid massive text logging
          #puts "There is a problem with your structured data on #{page.inspect}. Raw structured data text:\n\n#{text}\n\n"
        end
      }
      objects << item
    }
    #$stderr.puts "*" * 40
    #$stderr.puts "DONE #{__method__}. Object:\n\n#{objects.inspect}\n\n"
    return objects
  end
=end

  #12-30-14 kpr
  # provide support for wiki tables
  def self.transform(page, text)
    text = GenboreeRedmine.cleanRedmineWikiText(text)
    objects = []
    text.split(/\r?\n\s*\r?\n/).each{ |group|
      item = {}
      lineCount = 0
      tableCount = 0

      #keep track of times we also have a code block
      code_block_count = 0
      #have flag indicating that we're in or out of a code block
      code_block_open_flag = 0

      code_block_pattern = ""

      group.lines.each{ |line|
        #1-14-15
        #add support for other html code blocks, in this case targeting code snippet blocks

        #check to see if we should start an open code block and we're not already in an open block
        if(line =~ /^\<[a-zA-Z0-9]*\>/ and code_block_open_flag == 0) 
          item["code_block_#{code_block_count}"] = line.chomp

          code_block_pattern_tmp = line.split(">")[0]
          code_block_pattern = code_block_pattern_tmp.split("<")[1]

          #set open code block flag to 1
          code_block_open_flag = 1

          code_block_count += 1

        #then check to see if we're in an open code block, if so keep adding the block members
        elsif(code_block_open_flag == 1)
             

          code_block_count += 1

          #check to see if we need to close code block
          if line =~ /\<\/#{code_block_pattern}\>/
            item["code_block_#{code_block_count}"] = line.chomp
            code_block_open_flag = 0
          #otherwise just keep adding
          else
            item["code_block_#{code_block_count}"] = CGI::escapeHTML(line.chomp)
          end

        #11-18-14 kpr
        #need to allow for other types of data structures to be 
        # stored outside of just standard hash
        #check for table formatting (line starting with '|')
        elsif(line =~ /^\|\ /)
          item["t_#{tableCount}"] = line.chomp
          tableCount += 1

        elsif(line =~ /(\w+):\s*(\S.*)/)
          item[$1] = $2.chomp
        elsif(line =~ /^\s*\{\{fnlist\}\}\s*$/)
          # No-op
          # Skip this tag which Redmine adds to indicate "List any page-attached files here"
        else
          #commenting out this line to avoid massive text logging
          #puts "There is a problem with your structured data on #{page.inspect}. Raw structured data text:\n\n#{text}\n\n"
        end
        lineCount += 1
      }

      #11-18-14 kpr
      # also add some informative hash elements to assist with iterations
      item["table_row_count"] = tableCount
      #item["ATTENTION!!!!!!!!!!!!!!!!!!!!!!!!!!"] = tableCount

      #1-14-15
      # also add info for length of code block count
      item["code_block_count"] = code_block_count


      objects << item
    }
    #$stderr.puts "*" * 40
    #$stderr.puts "DONE #{__method__}. Object:\n\n#{objects.inspect}\n\n"
    return objects
  end



  # Removes known Redmine shims/additions to raw wiki text from Redmine. Things
  #   it or plugins add that don't otherwise appear on wiki "edit" UI.
  # @param [String] Raw wiki text from redmine
  # @return [String] Cleaned up text.
  def self.cleanRedmineWikiText(text)
    retVal = text.gsub(/^\s*\{\{fnlist\}\}\s*$/, '')
    return retVal
  end

  #-- ERROR PAGES --#
  ##
  # 404 Error page.  Generated when wiki page is missing.
  # +page+: Name of the page attempted to access
  def self.missing(page)
    return <<-HTML
    <h2 style='text-align: center; margin-top: 100px;'>
    <i class='fa fa-question-circle'></i>
    We are sorry, but we cannot find that page</h2>
    <p style='text-align: center;'>Error 404: this may happen if you have entered
    the URL incorrectly, or the page no longer exists</p>
    HTML
  end
  ##
  # All other Error pages.  Generated when a non-200 response code is detected.
  # +code+: The error code generated (typically from the Redmine response)
  def self.error(code)
    return <<-HTML
    <h2 style='text-align: center; margin-top: 100px;'>
    <i class='fa fa-exclamation-triangle'></i>
    We are sorry, but an error has occurred</h2>
    <p style='text-align: center;'>Error #{code}: this happened because of an
    internal error.  It might be resolved on its own so please retry your request
    in a few minutes.  If you see this message repeatedly, please contact the
    administrator.</p>
    HTML
  end

  # Get the list of splash elements by calling Redmine and transforming.
  def self.getRedminePage(server, wikiPageName)
    uri = "#{server.redmineUrl}/projects/#{server.redmineProject}"
    uri += "/wiki/#{wikiPageName}.json?key=#{server.apiKey}"
    response = Net::HTTP.get_response(URI.parse(uri))
    if (response.code.to_i == 200)
      text = JSON.parse(response.body)["wiki_page"]["text"]
      return GenboreeRedmine.transform(wikiPageName, text)
    else
      puts "Error grabbing #{wikiPageName} from Wiki! Code: #{response.code}"
      return []
    end
  end

  #function parses out the specific hash in the supplied array of 
  # hashes based on matching id
  def self.getRedminePageSubset(arrayOfHashes, id)
    #returnHash = Hash.new(0)
    # 4-8-15 kpr nil hash works out much better for not showing anything by default on subsequent pages
    returnHash = Hash.new()
    #find hashes in splashContentArr based on ID name
    hsh_found_loc = -1
    arrayOfHashes.each_with_index{ |hsh, pos|
      if hsh["ID"] == id
        hsh_found_loc = pos
        break
      end
    }

    if hsh_found_loc != -1
      returnHash = arrayOfHashes[hsh_found_loc]
    else
      #puts "Error: could not find #{id} content section in #{arrayOfHashes.inspect}"
      #puts "#{Time.now}\tError: could not find #{id} content section"
    end

    return returnHash

  end


  def self.getRedminePageCollectionViaPattern(arrayOfHashes, pattern)
    returnArr = []

    arrayOfHashes.each_with_index{ |hsh, pos|
      if hsh["ID"] =~ /^#{pattern}/
        returnArr.push(hsh)
      end
    }

    return returnArr
  end
 

  # Get default page ()
  def self.getRedmineStartPage(server)
    wikiPageName = 'Menu'
    uri = "#{server.redmineUrl}/projects/#{server.redmineProject}"
    uri += "/wiki/#{wikiPageName}.json?key=#{server.apiKey}"
    response = Net::HTTP.get_response(URI.parse(uri))
    if (response.code.to_i == 200)
      text = JSON.parse(response.body)["wiki_page"]["text"]
      t = text.match(/defaultAction: *(\S+)\s/)
      return t[1] if not t.nil?
    else
      puts "Error grabbing #{wikiPageName} from Wiki! Code: #{response.code}"
    end
    return 'splash'
  end


end #class GenboreeRedmine
