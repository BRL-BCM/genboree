#!/usr/bin/env ruby

require 'brl/util/util'
require 'brl/genboree/genboreeUtil'
require 'brl/util/textFileUtil'

module BRL ; module Genboree ; module ToolPlugins ; module Tools ; module NameSelectorTool

  class NameMatch
    attr_accessor :aliases, :matched, :matchType, :matchSubtype, :found, :done
    
    def initialize(aliases=[], matchedAlias=nil)
      @aliases = aliases
      @matched = matchedAlias
      @matchType = nil
      @matchSubtype = nil
      @found = false
      @done = false
    end
    
    def self.parseNameStr(line)
      nameMatch = NameMatch.new()
      line.split(/\s+/).each { |otherName|
        unless(otherName =~ /^[^\?\*]+$/)       # then a pattern alias
          otherName.gsub!(/\./, '\\.')
          otherName.gsub!(/\?/, '.')
          otherName.gsub!(/\*/, '.*')
        end
        nameMatch.aliases << %r{^#{otherName}$}
      }
      return nameMatch
    end
    
    def aliasesToAttr()
      retVal = "searchTermsMatched="
      @aliases.each_index { |ii|
        theAlias = @aliases[ii]
        theAlias = theAlias.source
        theAlias.gsub!(/^\^/, '')
        theAlias.gsub!(/\$$/, '')
        theAlias.gsub!(/\\./, 7.chr)
        theAlias.gsub!(/\.\*/, '*')
        theAlias.gsub!(/\./, '?')
        theAlias.gsub!(/#{7.chr}/, '.')
        retVal << theAlias
        retVal << ',' unless(ii == (@aliases.length - 1))
      }
      return retVal
    end
      
    def to_s()
      retVal = "NameMatch [#{self.object_id}]:\n    - found => #{@found}\n    - done => #{done}\n    - aliases:\n    - matched alias idx: #{@matched}\n    - matched type: #{@matchType}\n    - matched subtype: #{@matchSubtype}\n"
      @aliases.each_index { |ii|
        retVal << "      . #{@aliases[ii]}\n"
      }
      return retVal
    end
  end
  
  class LFFNameSelector
    def initialize(optsHash)
      @lffFiles = optsHash['--lffFileList'].gsub(/\\/,'').split(/,/)
      @lffFiles.map!{|xx| xx.strip ; xx.gsub(/\\,/, ',') }
      @nameListFile = optsHash['--nameListFile'].gsub(/\\/,'')
      @outputType = optsHash['--outputType'].gsub(/\\/,'').gsub(/\\,/, ',').gsub(/\\"/, "'") # '
      @outputSubtype = optsHash['--outputSubtype'].gsub(/\\/,'').gsub(/\\,/, ',').gsub(/\\"/, "'") # '
      @outputClass = optsHash.key?('--outputClass') ? optsHash['--outputClass'].gsub(/\\/,'').gsub(/\\,/, ',').gsub(/\\"/, "'")  : 'Selected' # '      
      @kgAliasFile = optsHash.key?('--kgAliasFile') ? optsHash['--kgAliasFile'].gsub(/\\/,'') : nil
      @selectMode = optsHash.key?('--selectMode') ? optsHash['--selectMode'].strip : 'full'
      
      # Read names & aliases list
      self.readNamesList()

      # Read kgAliasFile, if any
      self.readKgAliasFile() unless(@kgAliasFile.nil?)
      
    end

    def readNamesList()
      $stderr.puts "#{Time.now} NAME SELECTOR: Begin reading names for selection..."
      @namesList = []
      @exactNames = {}
      reader = BRL::Util::TextReader.new(@nameListFile)
      reader.each { |line|
        next if(line !~ /\S/ or line =~ /^\s*#/)
        line.strip!
        nameMatch = NameMatch.parseNameStr(line)
        @namesList << nameMatch
        line =~ /^(\S+)/
        @exactNames[$1] = nil
      }
      reader.close()
      $stderr.puts "#{Time.now} NAME SELECTOR: ...done. Read #{@namesList.length} names (#{@exactNames.size} exact)."
      return
    end
      
    def readKgAliasFile()
      $stderr.puts "#{Time.now} NAME SELECTOR: Go through kgAliases file and see if any match our names."
      # 1) Read the kgAlias file into memory
      kgAccMatched = Hash.new { |hh,kk| hh[kk] = [] }
      kgAcc2Aliases = Hash.new { |hh,kk| hh[kk] = [] }
      # First, suck in the data
      reader = BRL::Util::TextReader.new(@kgAliasFile)
      reader.each { |line|
        next if( line !~ /\S/ )
        accNum, accAlias = line.strip.split(/\s+/)
        kgAcc2Aliases[accNum] << accAlias
      }
      $stderr.puts "#{Time.now}                Done, read in #{kgAcc2Aliases.size} aliases."
      $stderr.puts "#{Time.now}                Now see which aliases have something to do with our names."
      # Now check if the acc or the alias matches any of our desired NameMatches
      progCount = 0
      kgAcc2Aliases.each_key { |accNum|
        accAliases = kgAcc2Aliases[accNum]
        progCount += 1
        $stderr.puts "#{Time.now}                - checked #{progCount} kg accNums" if(progCount > 0 and (progCount % 2000 == 0))
        # Check if accNum matches any name/alias
        @namesList.each { |nameMatch|
        foundMatch = false
          nameMatch.aliases.each { |otherName|
            if(accNum =~ otherName)
              kgAccMatched[accNum] << nameMatch
              foundMatch = true
              break
            else # accNum doesn't match this name, how about one of the kgAliases for the accNum?
              accAliases.each { |accAlias|
                if(accAlias =~ otherName)
                  kgAccMatched[accNum] << nameMatch
                  foundMatch = true
                  break # stop looking at name's aliases
                end
              }
              break if(foundMatch) # we matched a kgAlias vs a name alias
            end
          }
        }
      }
      reader.close()
      $stderr.puts "#{Time.now} NAME SELECTOR: done, #{kgAccMatched.length} kgAliases matched our names."
      # 2) Go through each kgAlias that had *some* match and
      #    add it and all its aliases to each nameMatch it matched
      kgAccMatched.each_key { |accNum|
        kgAliases = kgAcc2Aliases[accNum]
        kgAliases << accNum
        # 2.a) Go through each nameMatch and decide which kgAliases to add
        kgAccMatched[accNum].each { |nameMatch|
          # For each kgAlias, see if it is in the nameMatch's aliases list already.
          # If not, add it. Else not needed to add it.
          kgAliases.each { |kgAlias|
            alreadyInAliases = false
            nameMatch.aliases.each { |otherName|
              if(kgAlias =~ otherName)
                alreadyInAliases = true
                break
              end
            }
            nameMatch.aliases << /^#{kgAlias}$/ unless(alreadyInAliases)
          }
        }
      }
      $stderr.puts "#{Time.now} NAME SELECTOR: Augmented our names list with possible aliases."
      return
    end
    
    def selectAnnos()
      # Go through each lff file
      @lffFiles.each { |lffFile|
        $stderr.puts "#{Time.now} NAME SELECTOR: Examine each record in #{lffFile} and try to match it against our names."
        reader = BRL::Util::TextReader.new(lffFile)
        line = nil
        $stdout.sync = true
        reader.each { |line|
          if(reader.lineno > 0 and (reader.lineno % 10_000 == 0))
            $stderr.puts "   - done #{reader.lineno} lines "
          end
          next if(line !~ /\S/ or line =~ /^\s*#/ or line =~ /^\s*\[/)
          ff = line.split(/\t/)
          ff.map! {|xx| xx.strip }
          ff[10] = '.' if(ff.size < 11 or ff[10].to_s.empty?)
          ff[11] = '.' if(ff.size < 12 or ff[11].to_s.empty?)
          lffName = ff[1]
          # $stderr.puts "    lffName: #{lffName}"
          if(@selectMode == 'full')
            matchedLff = false
            nameMatch = nil
            # Go through each name/pattern/aliasList and try to match it
            @namesList.each { |nameMatch|
              next if(nameMatch.done)
              # Nothing has matched any of the aliases of this NameMatch yet.
              # Go through each otherName for this name
              nameMatch.aliases.each_index { |ii|
                otherName = nameMatch.aliases[ii]
                # If matches, then if already matched vs 1+ annos, then:
                # *ONLY* match this anno also if: the track is the same.
                # Otherwise is first match for this NameMatch for any alias.
                if(lffName =~ otherName and
                    ((nameMatch.found and ff[2] == nameMatch.matchType and ff[3] == nameMatch.matchSubtype) or
                    !nameMatch.found))
                  matchedLff = nameMatch.found = true
                  nameMatch.matched = ii
                  nameMatch.matchType = ff[2]
                  nameMatch.matchSubtype = ff[3]
                  ff[0], ff[2], ff[3] = @outputClass, @outputType, @outputSubtype
                  ff[12] = "#{nameMatch.aliasesToAttr()}; #{ff[12]} "
                  puts ff.join("\t")
                end
              }
              break if(matchedLff) # don't go through the rest of the aliases, we found one that matched.
            }
          elsif(@selectMode == 'exact')
            # Look up the name exactly
            if(@exactNames.key?(lffName))
              ff[0], ff[2], ff[3] = @outputClass, @outputType, @outputSubtype
              ff[12] = "searchTermMatched=#{lffName}; #{ff[12]} "
              puts ff.join("\t")
            end
          elsif(@selectMode == 'isoform')
            # Look up the isoform part of the name, assuming numbered versions
            lffName =~ /^(\S+)\.\d+$/
            isoformBase = ($1.nil? ? lffName : $1)
            if(@exactNames.key?(isoformBase))
              ff[12] = "searchTermMatched=#{isoformBase}; #{ff[12]} "
              ff[0], ff[2], ff[3] = @outputClass, @outputType, @outputSubtype
              puts ff.join("\t")
            end
          end
        }
        # Clean nameMatches: if 'found', now mark 'done'
        # self.markUsedNames()
        reader.close()
      }
      $stderr.puts "#{Time.now} NAME SELECTOR: Done processing lff files"
      return BRL::Genboree::OK
    end
    
    def markUsedNames()
      @namesList.each { |nameMatch|
        nameMatch.done = true if(nameMatch.found)
      }
      return 
    end
              
    def LFFNameSelector.processArguments()
      # We want to add all the prop_keys as potential command line options
      optsArray = [ ['--lffFileList', '-f', GetoptLong::REQUIRED_ARGUMENT],
                    ['--nameListFile', '-n', GetoptLong::REQUIRED_ARGUMENT],
                    ['--outputType', '-t', GetoptLong::REQUIRED_ARGUMENT],
                    ['--outputSubtype', '-u', GetoptLong::REQUIRED_ARGUMENT],
                    ['--selectMode', '-m', GetoptLong::OPTIONAL_ARGUMENT],
                    ['--outputClass', '-c', GetoptLong::OPTIONAL_ARGUMENT],
                    ['--kgAliasFile', '-k', GetoptLong::OPTIONAL_ARGUMENT],
                    ['--help', '-h', GetoptLong::NO_ARGUMENT]
                  ]
      progOpts = GetoptLong.new(*optsArray)
      LFFNameSelector.usage("USAGE ERROR: some required arguments are missing") unless(progOpts.getMissingOptions().empty?)
      optsHash = progOpts.to_hash
      LFFNameSelector.usage() if(optsHash.empty? or optsHash.key?('--help'));
      return optsHash
    end
  
    # * *Function*: Displays some basic usage info on STDOUT
    # * *Usage*   : <tt>  BRL::PASH::PashToLff.usage("WARNING: insufficient info provided")  </tt>
    # * *Args*  :
    #   - +String+ Optional message string to output before the usage info.
    # * *Return* :
    #   - +none+
    # * *Throws*  :
    #   - +none+
    # --------------------------------------------------------------------------
    def LFFNameSelector.usage(msg='')
      unless(msg.empty?)
        puts "\n#{msg}\n"
      end
      puts "
  
  PROGRAM DESCRIPTION:
    
    Selects annotations from LFF files based on their names. A file of all
    names and aliases is required. The tracks to extract from are also required,
    listed in a file.
    
    The tracks will be searched *in the order* given in the file. Once a name,
    OR any of its aliases, matches 1+ annotations in a track the remaining
    tracks will NOT be searched for that name. (This prevents annotation group
    or gene corruption by combining groups/genes from various tracks together,
    which very often creates a complete mess.)
    
    NOTE: within a track with 1+ matching annotations, ALL ANNOTATIONS matching
    ALL of the aliases or patterns will be extracted. Be careful with overly
    broad patterns that match all sorts of stuff!
    
    Each name is on its own line in the name list file, along with its aliases
    if any. Each name, alias, or pattern is separated by whitespace
    (tab or space).
    
    This tool ONLY searches the annotations names. Simple patterns are supported
    in the form of * (0 or more letters) and ? (1 letter). Be careful with
    overly broad patterns that match all sorts of things within a track!
    
    As a special, non-generic option, a 'known gene aliases' file can also be
    used as a source of aliases. The correct kgAlias file must be provided with
    the -k argument. This is useful when extracting from the known gene track
    from UCSC for one species or another.
    
    COMMAND LINE ARGUMENTS:
      --lffFileList     | -f  => Source LFF files, separated by commas ONLY.
      --nameListFile    | -n  => File with names and aliases. Each name on its
                                 own line, along with its aliases.
      --outputType      | -t  => The output track's 'type'.
      --outputSubtype   | -u  => The output track's 'subtype'.
      --outputClass     | -c  => [Optional] The output track's 'class'.
                                 Defaults to 'Selected'.
      --selectMode      | -m  => [Optional] Use a more specific search mode, rather
                                 than the default of 'full'. You can search using
                                 'exact' or 'isoform' modes, to do exact name
                                 matching or isoform/variant matching respectively.
      --kgAliasFile     | -k  => [Optional] Specify a kgAliases file to use in
                                 addition to the provided aliases.
      --help            | -h  => [Optional flag]. Print help info and exit.
  
    SPECIAL CHARACTERS:
    
    Single Quotes ('):
    If a track type/subtype contains a single-quote, pass to the program
    as \" . This will usually mean the argument should be in single quotes
    when run under sh/bash.
    
    USAGE:
    LFFNameSelector -f track1.lff,track2.lff -l tracksToSearch.txt
      -n names.txt -t MyOutput -u Tracks
    
  ";
      exit(BRL::Genboree::USAGE_ERR);
    end # def LFFNameSelector.usage(msg='')
  end # class LFFNameSelector
end ; end ; end ; end ; end # namespace

# ##############################################################################
# MAIN
# ##############################################################################
begin
  optsHash = BRL::Genboree::ToolPlugins::Tools::NameSelectorTool::LFFNameSelector.processArguments()
  $stderr.puts "#{Time.now()} NAME SELECTOR - STARTING"
  selector = BRL::Genboree::ToolPlugins::Tools::NameSelectorTool::LFFNameSelector.new(optsHash)
  $stderr.puts "#{Time.now()} NAME SELECTOR - INITIALIZED"
  exitVal = selector.selectAnnos()
rescue Exception => err # Standard capture-log-report handling:
  errTitle =  "#{Time.now()} NAME SELECTOR - FATAL ERROR: The name selector exited without processing all the data, due to a fatal error.\n"
  msgTitle =  "FATAL ERROR: The name selector exited without processing all the data, due to a fatal error.\nPlease contact the Genboree admin. This error has been dated and logged.\n"
  errstr   =  "   The error message was: '#{err.message}'.\n"
  errstr   += "   The complete back-trace is:\n\"\n" + err.backtrace.join("\n") + "\n\""
  puts msgTitle
  $stderr.puts errTitle + errstr
  exitVal = BRL::Genboree::FATAL
end
$stderr.puts "#{Time.now()} NAME SELECTOR - DONE" unless(exitVal != 0)
exit(exitVal)
