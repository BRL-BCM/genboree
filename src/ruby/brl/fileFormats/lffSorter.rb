#!/usr/bin/env ruby
=begin
=end

# ##############################################################################
# REQUIRED CLASSES/MODULES
# ##############################################################################
require 'getoptlong'						# for GetoptLong class (command line option parse)
require 'brl/util/util'					# for to_hash extension of GetoptLong class
require 'brl/util/propTable'
require 'brl/util/textFileUtil' # For TextReader/Writer classes
require 'brl/genboree/genboreeUtil'

module BRL; module FileFormats
	# ---------------------------------------------------------------------------
	# ERROR Classes
	# ---------------------------------------------------------------------------
  class LFFParseError < StandardError
    def message=(value)
      @message = value
    end
  end
  
 	# ---------------------------------------------------------------------------
	# Main Class
	# ---------------------------------------------------------------------------
  class LFFSorter
    FIELD_MAP = {
                  'class' => 0,
                  'lffclass' => 0,
                  'name' => 1,
                  'type' => 2,
                  'lfftype' => 2,
                  'subtype' => 3,
                  'lffsubtype' => 4,
                  'chrom' => 4,
                  'tstart' => 5,
                  'tstop' => 6,
                  'tend' => 6,
                  'strand' => 7,
                  'orient' => 7,
                  'phase' => 8,
                  'score' => 9,
                  'qstart' => 10,
                  'qstop' => 11,
                  'acomment' => 12,
                  'scomment' => 13,
                  'fcomment' => 14
                }
                
    DEFAULT_ORDER = [ 4, 5, 6, 0, 2, 3, 7, 1, 9, 10, 11 ]

    def initialize(optsHash=nil)
      @sortCols = DEFAULT_ORDER
      self.config(optsHash) unless(optsHash.nil?)
    end
    
    def config(optsHash)
      @lffFile = optsHash['--lffFile'].strip
      @sortColumnStr = optsHash['--sortColumns']
      @sortColumnStr = @sortColumnStr.strip unless(@sortColumnStr.nil?)
      @minusSeparate = optsHash.key?('--minusSeparate')
      @numChromSort = optsHash.key?('--numChromSort')
      @attrSort = optsHash.key?('--sortAttributes')
      
      # Determine sort column order
      unless(@sortColumnStr.nil?)
        @sortCols = @sortColumnStr.split(/,/)
        @sortCols.map! { |xx|
          newVal = xx.downcase
          if(FIELD_MAP.key?(newVal))
            newVal = FIELD_MAP[newVal]
          elsif(newVal =~ /^(\d+)$/)
            newVal = $1.to_i
            raise "\n\nERROR: there is no column '#{newVal}'\n\n" if(newVal < 0)
          else
            raise "\n\nERROR: there is no column '#{xx}'\n\n"
          end
          newVal
        }
      end
      @sortCols.unshift(7) if(@minusSeparate)
      return 
    end
    
    def readLFF()
      @lffArray = []
      reader = BRL::Util::TextReader.new(@lffFile)
      reader.each { |line|
        next if(line !~ /\S/ or line =~ /^\s*[#|\[]/)
        line.strip!
        ff = line.split(/\t/)
        next if(ff.length == 3 or ff.length == 7)
        raise "\n\nERROR: not a valid LFF line:\n\n#{line}\n\n" unless(ff.length >= 10)
        ff[0] = ff[0].to_sym
        ff[1] = ff[1].to_sym
        ff[2] = ff[2].to_sym
        ff[3] = ff[3].to_sym
        ff[4] = ff[4].to_sym
        ff[5] = ff[5].to_i
        ff[6] = ff[6].to_i
        ff[7] = ff[7].to_sym
        ff[8] = ff[8].to_i
        ff[9] = (ff[9].strip == '.') ? 1.0 : ff[9].to_f
        # Fills actual nils or the actual values
        ff[10] = ff[10]
        ff[11] = ff[11]
        ff[12] = ff[12]
        ff[13] = ff[13]
        ff[14] = ff[14]
        # use the Symbol for '.' also, to save memory, if '.' is used
        ff[10] = :'.' if(ff[10].nil? or ff[10].strip == '.')
        ff[11] = :'.' if(ff[11].nil? or ff[11].strip == '.')
        (12..14).each { |ii| ff[ii].strip! unless(ff[ii].nil?) }
        
        # Convert so start < end
        if(ff[5] > ff[6])
          ff[5], ff[6] = ff[6], ff[5]
        end
        unless(ff[10].nil? or ff[11].nil? or (ff[10] == :'.') or (ff[11] == :'.'))
          ff[10] = ff[10].to_i
          ff[11] = ff[11].to_i
          if(ff[10] > ff[11])
            ff[10], ff[11] = ff[11], ff[10]
          end
        end
        # Pre-calculate the chrom sort key and add to the end, if needed
        if(@numChromSort)
          chromSortKey = ff[4].to_s.downcase
          if(chromSortKey =~ /([0-9MXY]+|Un)$/)
            ff << $1.downcase
          else
            ff << chromSortKey
          end
        end
        # Sort attributes if asked
        sortAttributes(ff) if(@attrSort)
        @lffArray << ff
      }
      reader.close()
      return  
    end
    
    def sortAttributes(ff)
      return if(ff[12].nil? or ff[12] !~ /\S/ or ff[12] =~ /^\s*\.\s*$/)
      attrValPairs = ff[12].strip.split(/;/)
      # Sets up a sort of Schwartzian Transform
      attrValPairs.map! { |xx|
        xx.strip!
        if(xx =~ /^\s*$/)
          xx = nil
        elsif(xx =~ /^([^=]{1,255})\s*=\s*(.+)$/)
          xx = [ $1.strip, $2.strip ]
        else
          xx = [ xx, nil ]
        end
        xx
      }
      # Get rid of nil AVP entries
      attrValPairs.compact!
      # Do actual sort using the Transform
      attrValPairs.sort! { |aa, bb|
        retVal = (aa[0].downcase <=> bb[0].downcase)
        (retVal = (aa[0] <=> bb[0])) if(retVal == 0)
        unless (aa[1].nil? or bb[1].nil?) 
          (retVal = (aa[1].downcase <=> bb[0].downcase)) if(retVal == 0)
          (retVal = (aa[1] <=> bb[1])) if(retVal == 0)
        end
        retVal
      }
      ff[12] = ''
      attrValPairs.each { |pair|
        if(pair[1].nil?) 
          ff[12] += "#{pair[0]}; "
        else
          ff[12] += "#{pair[0]}=#{pair[1]}; "
        end
      }
      return
    end
    
    def sortLFF()
      aa,bb = nil # predeclare for speed
      @lffArray.sort! { |aa,bb|
        # Go through each sort column in order
        retVal = 0
        idx = nil
        aaLastIdx = aa.lastIndex
        bbLastIdx = bb.lastIndex
        @sortCols.each { |idx|
          if( idx == 4 ) # chrom column
            if(@numChromSort) # SPECIAL CHROM SORT: deal with chrom column numerically, then alpha
              aaChromKey = aa[aaLastIdx]
              bbChromKey = bb[bbLastIdx]
              if( aaChromKey =~ /^\d+$/ )
                if( bbChromKey =~ /^\d+$/ )
                  retVal = (aaChromKey.to_i <=> bbChromKey.to_i)
                else
                  retVal = -1
                end
              elsif( bbChromKey =~ /^\d+$/ )
                retVal = 1
              else
                retVal = ( aaChromKey <=> bbChromKey )
              end
            else # NORMAL CHROM SORT
              retVal = (aa[idx] <=> bb[idx])
            end
          elsif( idx == 5 or idx == 6 or idx == 8 or idx == 9 ) # coord column
            if(@minusSeparate and (aa[7] == :-) and (bb[7] == :-)) # SPECIAL COORD SORT: sort minus strand coords in reverse
              retVal = (bb[idx] <=> aa[idx])
            else # NORMAL COORD SORT
              retVal = (aa[idx] <=> bb[idx])
            end
          else # other (normal) column
            retVal = (aa[idx] <=> bb[idx])
          end
          break unless(retVal == 0)
        }
        retVal
      }
      return
    end
    
    def printAnnos()
      @lffArray.each { |ff|
        # remove chrom sort key if present
        ff.pop if(@numChromSort)
        puts ff.join("\t")
      }
      return
    end
    
    def sortAnnos()
      # Read in annos
      readLFF()
      # Sort annos
      sortLFF()
      # Dump annos
      printAnnos()
      return BRL::Genboree::OK
    end
    
    def LFFSorter.processArguments()
      # We want to add all the prop_keys as potential command line options
      optsArray = [ ['--lffFile', '-f', GetoptLong::REQUIRED_ARGUMENT],
                    ['--sortColumns', '-s', GetoptLong::OPTIONAL_ARGUMENT],
                    ['--numChromSort', '-c', GetoptLong::NO_ARGUMENT],
                    ['--minusSeparate', '-m', GetoptLong::NO_ARGUMENT],
                    ['--sortAttributes', '-a', GetoptLong::NO_ARGUMENT],
                    ['--help', '-h', GetoptLong::NO_ARGUMENT]
                  ]
      progOpts = GetoptLong.new(*optsArray)
      LFFSorter.usage("USAGE ERROR: some required arguments are missing") unless(progOpts.getMissingOptions().empty?)
      optsHash = progOpts.to_hash
      LFFSorter.usage() if(optsHash.empty? or optsHash.key?('--help'));
      return optsHash
    end
  
    # * *Function*: Displays some basic usage info on STDOUT
    # * *Usage*   : <tt>  BRL::PASH::LFFSorter.usage("WARNING: insufficient info provided")  </tt>
    # * *Args*  :
    #   - +String+ Optional message string to output before the usage info.
    # * *Return* :
    #   - +none+
    # * *Throws*  :
    #   - +none+
    # --------------------------------------------------------------------------
    def LFFSorter.usage(msg='')
      unless(msg.empty?)
        puts "\n#{msg}\n"
      end
      puts "
  
  PROGRAM DESCRIPTION:
    
    Sorts an LFF file using the provided columns. The default sort uses these
    columns in a radix sort:
  
  chrom, tstart, tstop, class, type, subtype, strand, name, score, qstart, qstop
      
    The sort columns to use can be provided as a comma-separated list of indices
    or of column names:
      class
      name
      type
      subtype
      chrom
      tstart
      tstop
      strand
      phase
      score
      qstart
      qstop
      acomment
      scomment
      fcomment
    
    The optional flag --minusSeparate causes the minus (-) strand to be sorted
    separately and in *reverse* coordinate order (i.e. 5'-3') AFTER the plus (+)
    strand.
    
    Output is on STDOUT.
        
    COMMAND LINE ARGUMENTS:
      --lffFile             | -f  => Source LFF file.
      --sortColumns         | -s  => [optional] A comma separated list of column
                                     names or indices indicating the columns to
                                     sort on.
      --minusSeparate       | -m  => [optional flag] Sort the minus (-) strand
                                     annotations in reverse order and after the
                                     plus strand.
      --numChromSort        | -c  => [optional flag] Try to sort the chromosome
                                     column using the number (or M,Un,X,Y).
                                     It will look for this at the END of the
                                     chromosome name, allowing numerical sort of
                                     scaffolds too. Will SLOW the sort!
      --sortAttributes      | -a  => [optional flag] Sort the ATTRIBUTE
                                     comments in the 13th column. Attributes are
                                     in the form of attr=value; remember. They
                                     are sorted by attribute name and then
                                     value for ties. SLOWEST OPTION!
      --help                | -h  => [optional flag]. Print help info and exit.
  
    USAGE:
    lffSorter -f myLFF.lff -s chrom,tstart,tstop > myLFF.sorted.lff
    
  ";
      exit(BRL::Genboree::USAGE_ERR);
    end # def LFFSorter.usage(msg='')  
  end
end ; end

# ##############################################################################
# MAIN
# ##############################################################################
begin
  optsHash = BRL::FileFormats::LFFSorter.processArguments()
  $stderr.puts "#{Time.now()} SORTER - STARTING"
  sorter = BRL::FileFormats::LFFSorter.new(optsHash)
  $stderr.puts "#{Time.now()} SORTER - INITIALIZED"
  exitVal = sorter.sortAnnos()
rescue Exception => err # Standard capture-log-report handling:
  errTitle =  "#{Time.now()} SORTER - FATAL ERROR: The sorter exited without processing all the data, due to a fatal error.\n"
  msgTitle =  "FATAL ERROR: The sorter exited without processing all the data, due to a fatal error.\nPlease contact the Genboree admin. This error has been dated and logged.\n"
  errstr   =  "   The error message was: '#{err.message}'.\n"
  errstr   += "   The complete back-trace is:\n\"\n" + err.backtrace.join("\n") + "\n\""
  puts msgTitle
  $stderr.puts errTitle + errstr
  exitVal = BRL::Genboree::FATAL
end
$stderr.puts "#{Time.now()} SORTER - DONE" unless(exitVal != 0)
exit(exitVal)
 