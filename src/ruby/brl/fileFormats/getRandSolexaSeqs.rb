#!/usr/bin/env ruby

# ##############################################################################
# REQUIRED CLASSES/MODULES
# ##############################################################################
require 'rubygems'
require 'gsl'
require 'brl/util/textFileUtil'
require 'brl/util/util'
# Retry load if doing facets 1.X way fails...maybe we have facets 2.X
begin
  require 'facet/enumerable/entropy'
  require 'facet/fileutils/wc'
rescue LoadError => lerr
  require 'facets/enumerable/entropy'
  require 'facets/fileutils/wc'
end  

# PROBLEM:
# - sequence input file is very large in bytes and number of records (T)
# - we can't just read in the huge file and shuffle/select
# - we want to randomly pick N records from this file
# - N << T
# - we *don't* want a biased sampling ; records from the end of the
#   file to be just as likely as ones from the beginning
# - we might reject some of the records up for consideration
# - we don't want to do *too* many passed through the file, but can
#   put up with maybe 2 or 3 if really needed (this should be made unlikely via code)

# APPROACH:
# - can't read in whole file at once...too much data to store
#   (1.3GB just to store ATGCs for 38x10^6 records), let alone all the
#   overhead and other stuff
# (1) therefore, we will decide *ahead* of time which lines will be output
#     . say we want N sequences
#     . 1st get total number of lines using wc (call this T)
#     . 2nd select 3*N random numbers from 0 to T-1
#     . these are line numbers ; we will output at most N of the 3*N selected
#     . select 3*N because some sequences will be for rejected ; so we over-select
#     in anticipation, which is ok because N << T
# (2) then we go through the file line by line and decide if the line one of the
#     ones we decided to consider
#     . if the considered line sucks, skip it...we selected 3*N possible lines just in case!
# (3) let M be the number of sequences we *actually* output in this iteration
# (4) if M < N even though 3*N were selected just in case, then we exhausted
#     the 3*N numbers before getting all the records we wanted.
#     . let N = N-M
#     . REPEAT process again starting at (1) using this new N as long as we don't select any lines that
#       were previously selected for consideration

# STORAGE COMPLEXITY:
# - O(N) 36 mers
# - O(N) line numbers
# - as long as N << T then this is cool

# PERFORMANCE COMPLEXITY:
# - should be avgO(T)
#   . to prevent too many passes through the secRecFile, we selected
#     3*N random lines up front
#   . in a very very unlucky universe, or if rejection criteria are
#     too stringent, you will see the worst case complexity: O(T^2), LOL

#--------------------------------------------------------------------
# (A) CONVENIENCE CLASSES
#--------------------------------------------------------------------
# SeqRec Class (will try not to store these, but here is if needed)
class SeqRec
  @@nameCounts = Hash.new { |hh,kk| hh[kk] = 0 }
  
  attr_accessor :channel, :tile, :xCoord, :yCoord, :sequence

  # Init from a line from the file  
  def initialize(recStr)
    @channel, @tile, @xCoord, @yCoord, @sequence = recStr.strip.split(/\s+/)
  end

  # Make a unique sequence name for this guy.
  # - use info with a guarrantee of uniqueness
  def seqName()
    unless(@seqName)
      seqName = "#{@channel}_#{@tile}_#{@xCoord}_#{@yCoord}"
      countStr = (@@nameCounts[seqName] += 1)
      @seqName = "#{seqName}.#{countStr}"
    end
    return @seqName
  end
  
  # Makes ~fasta record
  def to_s()
    return ">#{self.seqName()}\n#{@sequence}"
  end
  
  # Just to be clean
  def clear()
    @channel = @tile = @xCoord = @yCoord = @sequence = nil
    return
  end
end
#--------------------------------------------------------------------

#--------------------------------------------------------------------
# (B) CONVENIENCE METHODS
#--------------------------------------------------------------------
# Get @numSeqsToSelect random numbers from 0 to @totalNumLines
# . ensure all numbers a unique
# . ensure we haven't selected the random number previously
# . use GSL because @totalNumLines might be huge and we want *uniform* probability
# . add each random number to @selectedLines hash
def getRandomNumbers()
  @selectedLines = {}
  rng = Rng.alloc() # a *good* Random Number Generator from the GSL (this is important)
  # Loop while our hash doesn't have 3*N unique line numbers in it
  while(@selectedLines.size < (3*@numSeqsToSelect))
    # select a random number from 0 to total number of lines in file
    # . add it to the hash if we haven't seen it previously
    selectedLineNum = rng.uniform_int(@totalNumLines)
    @selectedLines[selectedLineNum] = nil unless(@seenLines.key?(selectedLineNum))
  end
  return
end

# REJECT SEQ CRITERIA:
# . we have seen sequence before
# . the sequence has Entropy <= 1.0 (like saying "50% or more of
#   the bases are the same letter, reject it", kinda)
# . the sequence has a '.' in it
def isSeqRecOk?(seqRec)
  retVal = true
  if(@seenSeqs.key?(seqRec.sequence)) # we've seen this sequence <= I don't like this criterion
    retVal = false
  elsif(seqRec.sequence =~ /\./) # it has a '.'
    retVal = false
  elsif(seqRec.sequence.entropy <= 1.0) # it has low Shannon Entropy (50%+ is the same letter)
    retVal = false
  end
  return retVal
end
#--------------------------------------------------------------------



#--------------------------------------------------------------------
# (C) BEGIN EXECUTION
#--------------------------------------------------------------------
# Script called ok?
if(ARGV.size < 2 or ARGV.index('-h') or ARGV.index('--help') or ARGV[1] !~ /^\d+$/)
  puts "\n\nUSAGE:\n\n    getRandSolexaSeqs.rb <seqsFile> <numSeqsToSelect>\n\n"
  exit(134)
end

# Set Up Globally Accessible Variables
@seenSeqs = {}                   # 36mers seen in any interation
@seenLines = {}                  # linenos seein in any interation
@totalSeqsOutput = 0             # count of how many seqs we've puts
@seqRecFile = ARGV[0]            # File to select sequences from?
@numSeqsToSelect = ARGV[1].to_i  # How many random sequences to select?
@selectedLines = {}              # Current randomly selected line numbers

# How many lines in huge file?
@totalNumLines = FileUtils.wc(@seqRecFile, 'lines')

loop {
  # Pick 3*N unique line numbers we haven't previously considered
  getRandomNumbers()
  
  # Go through file line by line and decide if to puts the line (as fasta) or not
  reader = BRL::Util::TextReader.new(@seqRecFile)
  reader.each { |line|
    next unless(@selectedLines.key?(reader.lineno)) # this isn't a line we selected!
    next if(line !~ /\S/ or line =~ /^\s*#/) # this line is blank or starts with #
    
    @seenLines[reader.lineno] = nil # we are going to consider this line now...mark it as seen
    
    seqRec = SeqRec.new(line)
    # Is this seq rec acceptable?
    acceptSeqRec = isSeqRecOk?(seqRec)
    
    # If acceptable, then:
    # . puts it
    # . record its sequence as being seen
    # . increment totalSeqsOutput
    if(acceptSeqRec)
      puts seqRec.to_s
      @seenSeqs[seqRec.sequence] = nil
      @totalSeqsOutput += 1
      seqRec.clear()
    end
    
    # Should we stop reading the file?
    # . if we have @totalSeqsOutput == @numSeqsToSelect, then we are done (skip rest of file)
    break if(@totalSeqsOutput >= @numSeqsToSelect)
  }
  reader.close()
  
  # Should we stop interating?
  # . we are *completely* done if @totalSeqsOutput == @numSeqsToSelect
  # . but if not, we will need another iteration (damn)
  #   _ we will need N-M more sequences to finish
  if(@totalSeqsOutput >= @numSeqsToSelect)
    break
  else
    @numSeqsToSelect -= @totalSeqsOutput    # new N is N-M, the number we are short
    @totalSeqsOutput = 0                    # reset M to 0
  end
}

# DONE
exit(0)

