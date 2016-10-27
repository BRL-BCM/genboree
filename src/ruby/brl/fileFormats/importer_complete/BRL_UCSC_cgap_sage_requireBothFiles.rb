#!/usr/bin/env ruby
### No warning!
$VERBOSE = nil

# ##############################################################################
# PURPOSE
# ##############################################################################
# Simple: convert from UCSC LongSAGE tags files to equivalent LFF version

# ##############################################################################
# REQUIRED LIBRARIES
# ##############################################################################
require 'brl/util/textFileUtil'
require 'brl/util/util'
require 'brl/genboree/genboreeUtil'

# ##############################################################################
# CONSTANTS
# ##############################################################################
FATAL = BRL::Genboree::FATAL
OK = BRL::Genboree::OK
OK_WITH_ERRORS = BRL::Genboree::OK_WITH_ERRORS
FAILED = BRL::Genboree::FAILED
USAGE_ERR = BRL::Genboree::USAGE_ERR

# ##############################################################################
# HELPER FUNCTIONS AND CLASS
# ##############################################################################

def processArguments()
  optsArray = [
                ['--trackName', '-t', GetoptLong::REQUIRED_ARGUMENT],
                ['--className', '-l', GetoptLong::REQUIRED_ARGUMENT],
                ['--cDirectoryInput', '-i', GetoptLong::REQUIRED_ARGUMENT],
                ['--fileToOutput', '-f', GetoptLong::REQUIRED_ARGUMENT],
                ['--cDirectoryOutput', '-d', GetoptLong::REQUIRED_ARGUMENT],
                ['--cgapSageFile', '-o', GetoptLong::REQUIRED_ARGUMENT],
                ['--cgapSageLibFile', '-p', GetoptLong::OPTIONAL_ARGUMENT],
                ['--help', '-h', GetoptLong::NO_ARGUMENT]
              ]
  progOpts = GetoptLong.new(*optsArray)
  optsHash = progOpts.to_hash
  # Try to use getMissingOptions() from Ruby's standard GetoptLong class
  optsMissing = progOpts.getMissingOptions()
  # If no argument given or request help information, just print usage...
  if(optsHash.empty? or optsHash.key?('--help'))
    usage()
    exit(USAGE_ERR)
  # If there is NOT any required argument file missing, then return an empty array; otherwise, report error
  elsif(optsMissing.length != 0)
    usage("Error: the REQUIRED args are missing!")
    exit(USAGE_ERR)
  else
    return optsHash
  end
end

def usage(msg='')
  puts "\n#{msg}\n" unless(msg.empty?)
  puts "

PROGRAM DESCRIPTION:
  Convert from UCSC LongSAGE tags file to equivalent LFF version.  

  COMMAND LINE ARGUMENTS:
    --trackName             | -t    => Track name for TAG:CGAP SAGE track.
                                       (type:subtype)
    --className             | -l    => Class name for TAG:CGAP SAGE track.
    --cDirectoryInput       | -i    => directory location of converting file 
    --fileToOutput          | -f    => converted file name
    --cDirectoryOutput      | -d    => directory location of converted file
    --cgapSageFile            | -o    => UCSC sage file to convert
    --cgapSageLibFile        | -p    => UCSC sageLib file to convert
    --help                  | -h   => [optional flag] Output this usage
                                      info and exit.

  USAGE:
  i.e. BRL_UCSC_cgap_sage_requireBothFiles.rb -t 'TAG:CGAP SAGE' -l 'mRNA and EST' -i /users/ybai/work/Project6/mRNA_EST/CGAP_SAGE -f CGAP_SAGE_LFF.txt -d /users/ybai/work/Project6/mRNA_EST/CGAP_SAGE -o cgapSage.txt.gz -p cgapSageLib.txt.gz 
"
end

class CgapSageLib
  attr_accessor :libId, :oldLibName, :newLibName, :totalTages, :totalTagsNoLinker, :uniqueTags, :quality, :tissue, :tissuePrep, :cellType, :keywords, :age, :sex, :mutaions, :otherInfo, :tagEnzyme, :ancherEnzyme, :cellSupplier, :libProducer, :laboratory, :refs  

  def initialize(line)
      @libId, @oldLibName, @newLibName, @totalTages, @totalTagsNoLinker, @uniqueTags, @quality, @tissue, @tissuePrep, @cellType, @keywords, @age, @sex, @mutations, @otherInfo, @tagEnzyme, @ancherEnzyme, @cellSupplier, @libProducer, @laboratory, @refs = nil
    unless(line.nil? or line.empty?)
      sage = line.chomp.split(/\t/)
      if(sage[0].nil? or sage[0].empty?)
        sage[1] =~ /(\S+)$/ ### not empty line
        sage[0] = $1  ### assign first match
      end
      @libId = sage[0]
      @oldLibName = sage[1]
      @newLibName = sage[2]
      @totalTages = sage[3]
      @totalTagsNoLinker = sage[4]
      @uniqueTags = sage[5]
      @quality = sage[6]
      @tissue = sage[7]
      @tissuePrep = sage[8]
      @cellType = sage[9]
      @keywords = sage[10]
      @age = sage[11]
      @sex = sage[12]
      @mutations = sage[13]
      @otherInfo = sage[14]
      @tagEnzyme = sage[15]
      @ancherEnzyme = sage[16]
      @cellSupplier = sage[17]
      @libProducer = sage[18]
      @laboratory = sage[19]
      @refs = sage[20] 
    end
  end

  def self.loadCgapSageLib(inputsHash)
    retVal = {}
    return retVal unless( inputsHash.key?('--cgapSageLibFile') ) ### if no this kind of file, just stop at here
    # Read cgapSageLib file
    reader = BRL::Util::TextReader.new(inputsHash['--cgapSageLibFile'])  ### get the whole file's contents one time
    reader.each { |line|
      next if(line !~ /\S/ or line =~ /^\s*#/) ### if it is empty or comment line
      rl = CgapSageLib.new(line)
      retVal[rl.libId] = rl ### use id as the key to the line
    }
    reader.close()
    return retVal
  end
end  

class MyConverter
  def initialize(inputsHash)
  end 
  def convert(inputsHash) 
    # Set the track type/subtype
    lffType, lffSubtype = inputsHash['--trackName'].strip.split(':')
    className = inputsHash['--className'].strip
    cDirectoryInput = inputsHash['--cDirectoryInput'].strip
    fileToOutput = inputsHash['--fileToOutput'].strip
    cDirectoryOutput = inputsHash['--cDirectoryOutput'].strip

    # Do we have the alias files? Load it if so.
    cgapSageLib = CgapSageLib.loadCgapSageLib(inputsHash)

    open("#{cDirectoryOutput}/#{fileToOutput}", 'w') do |f|
      cgapSageFile = inputsHash['--cgapSageFile'].strip
      unless(File.size?("#{cDirectoryInput}/#{cgapSageFile}"))
        $stderr.puts "WARNING: the file '#{cgapSageFile}' is empty. Nothing to do."
        exit(FAILED)
      end
      # CONVERT  TO LFF RECORDS USING WHAT WE HAVE SO FAR
      # Open the file
      reader = BRL::Util::TextReader.new("#{cDirectoryInput}/#{cgapSageFile}")
      line = nil
      begin
        # Go through each line
        reader.each { |line|
          next if(line =~ /^\s*#/ or line !~ /\S/)
          # Chop it up
          # bin chrom chromStart chromEnd name 
          ff = line.chomp.split(/\t/)
          ff[6] = ff[6].to_sym    #strand
   
          numLibs = ff[9].to_i
          libIds = ff[10].chomp(',').split(/,/).map{|xx| xx}
          freqs = ff[11].chomp(',').split(/,/).map{|xx| xx.to_i}
          tagTpms = ff[12].chomp(',').split(/,/).map{|xx| xx.to_f}

          unless(libIds.size == numLibs and freqs.size == numLibs and tagTpms.size == numLibs)
            $stderr.puts "\n\nERROR: this line doesn't have the right number of blocks (#{numLibs}).\n\n#{line}"
          end

          numLibs.times { |ii|  ### start from index 0
            ### print each block's information
            ### class, name, type, subtype, entry pint(chr), start, stop, strand, phase, score, qStart, qStop, attri_comments, seq, free_comments
            if(ff[6] == :'+')
              blockNum = ii+1
            else # - strand
              blockNum = numLibs-ii 
            end
            f.print "#{className}\t#{ff[4]}.Library_#{blockNum}\t#{lffType}\t#{lffSubtype}\t#{ff[1]}\t#{ff[2]}\t#{ff[3]}\t#{ff[6]}\t.\t#{ff[5]}\t.\t.\t"
            f.print "thickStart=#{ff[7]}; thickEnd=#{ff[8]}; numSnps=#{ff[13]}; numLibs=#{numLibs}; "
            if("#{libIds[ii]}" == "#{cgapSageLib[libIds[ii]].libId}")
              f.print "libIds=#{libIds[ii]}; oldLibName=#{cgapSageLib[libIds[ii]].oldLibName}; newLibName=#{cgapSageLib[libIds[ii]].newLibName}; totalTages=#{cgapSageLib[libIds[ii]].totalTages}; totalTagsNoLinker=#{cgapSageLib[libIds[ii]].totalTagsNoLinker}; uniqueTags=#{cgapSageLib[libIds[ii]].uniqueTags}; quality=#{cgapSageLib[libIds[ii]].quality}; tissue=#{cgapSageLib[libIds[ii]].tissue}; tissuePrep=#{cgapSageLib[libIds[ii]].tissuePrep}; cellType=#{cgapSageLib[libIds[ii]].cellType}; keywords=#{cgapSageLib[libIds[ii]].keywords}; age=#{cgapSageLib[libIds[ii]].age}; sex=#{cgapSageLib[libIds[ii]].sex}; otherInfo=#{cgapSageLib[libIds[ii]].otherInfo}; tagEnzyme=#{cgapSageLib[libIds[ii]].tagEnzyme}; ancherEnzyme=#{cgapSageLib[libIds[ii]].ancherEnzyme}; cellSupplier=#{cgapSageLib[libIds[ii]].cellSupplier}; libProducer=#{cgapSageLib[libIds[ii]].libProducer}; laboratory=#{cgapSageLib[libIds[ii]].laboratory}; refs=#{cgapSageLib[libIds[ii]].refs}"
            else
              f.print "libIds=#{libIds[ii]}"
            end

            # sequence (none)
            f.print "\t.\t"
            # summary (free form comments)
            f.print "."

            # done with record
            f.puts ""
          }
        } # reader close
        reader.close
      rescue => err
        $stderr.puts "ERROR: bad line found. Blank columns? Line num: #{reader.lineno}. Details: #{err.message}"
        $stderr.puts err.backtrace.join("\n")
        $stderr.puts "LINE: #{line.inspect}"
        exit(OK_WITH_ERRORS)
      end #begin
    end #open
  end
end


# ##############################################################################
# MAIN
# ##############################################################################
$stderr.puts "#{Time.now} BEGIN (Mem: #{BRL::Util::MemoryInfo.getMemUsageStr()})"
begin
  optsHash = processArguments()
  converter = MyConverter.new(optsHash)
  converter.convert(optsHash)
  $stderr.puts "#{Time.now} DONE"
  exit(OK)
rescue => err
  $stderr.puts "Error occurs... Details: #{err.message}"
  $stderr.puts err.backtrace.join("\n")
  exit(FATAL)
end
