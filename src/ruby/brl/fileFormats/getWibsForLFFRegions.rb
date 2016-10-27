#!/usr/bin/env ruby
$VERBOSE = nil

# ##############################################################################
# PURPOSE
# ##############################################################################
# Simple: takes one of David Wheeler's *.snps files and turns it into LFF.

# ##############################################################################
# REQUIRED LIBRARIES
# ##############################################################################
require 'brl/util/textFileUtil'
require 'brl/util/util'
require 'brl/util/propTable' # for PropTable class

# ##############################################################################
# CONSTANTS
# ##############################################################################
GZIP = BRL::Util::TextWriter::GZIP_OUT

# ##############################################################################
# HELPER FUNCTIONS
# ##############################################################################
# Process command line args
def processArguments()
  optsArray = [
                ['--lffFile', '-f', GetoptLong::REQUIRED_ARGUMENT],
                ['--wibDir', '-d', GetoptLong::REQUIRED_ARGUMENT],
                ['--wibExt', '-e', GetoptLong::REQUIRED_ARGUMENT],
                ['--chrom', '-c', GetoptLong::REQUIRED_ARGUMENT],
                ['--help', '-h', GetoptLong::NO_ARGUMENT]
              ]
  progOpts = GetoptLong.new(*optsArray)
  optsHash = progOpts.to_hash
  usage() if(optsHash.empty? or optsHash.key?('--help') or !optsHash.key?('--lffFile') or !optsHash.key?('--wibDir') or !optsHash.key?('--wibExt') or !optsHash.key?('--chrom') )
  return optsHash
end

def usage(msg='')
  puts "\n#{msg}\n" unless(msg.empty?)
  puts "

PROGRAM DESCRIPTION:
  Extracts the wib data from chromosome-wide wib files for specific regions
  defined in the lff file.
  
  The wib files must named by <chr><wibExt> so that a chromosome in the lff file
  can be used, with the --wibExt argument to find the relevant wib file to
  extract from.
  
  The extracted data file will:
  - be gzipped
  - be one per chromosome

  COMMAND LINE ARGUMENTS:
    --lffFile       |  -f    => Lff file containing the regions to get wibs for.
    --wibDir        |  -d    => Dir where the chr-wide wib data is
    --wibExt        |  -e    => Extension to add to chr name to make wib file.
    --chrom         |  -c    => What chromosome to process?
    --help          |  -h    => [optional flag] Output this usage info and exit.

  USAGE:
  
"
  exit(134)
end

# Method: suck in LFF file, hash by chr
def readLff(lffFile)
  lffRecs = []
  reader = BRL::Util::TextReader.new(lffFile)
  reader.each { |line|
    line.strip!
    next if(line =~ /^\s*#/ or line =~ /^\s*$/)
    ff = line.split("\t")
    chrom = ff[4]
    next unless(chrom == @chrom)
    ff[5] = ff[5].to_i
    ff[6] = ff[6].to_i
    ff[5],ff[6] = ff[6], ff[5] if(ff[5] > ff[6])
    lffRecs << ff
  }
  reader.close
  return lffRecs
end

# Method: sort the LFF records
def sortLffRecs(lffRecs)
  sortedLFFRecs = lffRecs
  sortedLFFRecs.sort! { |aa,bb|
    retVal = (aa[5] <=> bb[5])
    (retVal = (aa[6] <=> bb[6]) ) if(retVal == 0)
    retVal
  }
  return sortedLFFRecs
end

def dumpWibsForRecs(recs)
  # Open the wib file
  wibFile = @wibDir + '/' + @chrom + @wibExt
  reader = BRL::Util::TextReader.new(wibFile)
  # Open a writer for this chr
  writer = BRL::Util::TextWriter.new("#{@chrom}.wib.subset.gz", "w+", GZIP)
  lc = 0
  line = nil
  reader.each { |line|
    lc += 1
    line.strip!
    coord, value = line.split("\t")
    coord = coord.to_i
    $stderr.print '.' if(coord > 0 and (coord % 1_000_000 == 0))
    # Is the coordinate in any of the regions?
    recs.each { |rec|
      if(coord >= rec[5] and coord <= rec[6])
        writer.puts line
        break
      end
    }
  }
  $stderr.puts "[ processed #{lc} values ]"
  $stderr.puts "[ last line: ]\n\n#{line.inspect}"
  # Close/cleanup
  writer.close
  reader.close
  return
end

# ------------------------------------------------------------------------------

# ##############################################################################
# MAIN
# ##############################################################################
# 1) Parse params\
$stderr.puts "#{Time.now} STARTING"
optsHash = processArguments()
@lffFile = optsHash['--lffFile']
@wibDir = optsHash['--wibDir'].strip.gsub(/\/$/, '')
@wibExt = optsHash['--wibExt']
@chrom = optsHash['--chrom']
$stderr.puts "#{Time.now} DONE: parsing params"
# 2) Suck in LFF data
lffRecs = readLff(@lffFile)
$stderr.puts "#{Time.now} DONE: read lff file:\n\n" ; lffRecs.each {|rec| $stderr.puts rec.join("\t")} ; $stderr.puts "\n\n"
# 3) Sort the LFF data
lffRecs = sortLffRecs(lffRecs)
GC.start()
$stderr.puts "#{Time.now} DONE: sort lff recs:\n\n" ; lffRecs.each {|rec| $stderr.puts rec.join("\t")} ; $stderr.puts "\n\n"
# 4) Output relevant wib values for each chr
dumpWibsForRecs(lffRecs)
$stderr.puts "#{Time.now} END"
exit(0)
