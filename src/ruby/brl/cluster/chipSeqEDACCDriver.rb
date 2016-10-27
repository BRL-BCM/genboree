#!/usr/bin/env ruby
require 'brl/util/util'

module BRL
module EDACC
# Class that performs peak finding on an input bed file
# and generates a Genboree track corresponding to level 2
# analysis data and metadata according to the EDACC
# recommendation document
class ChipSeqEDACCDriver
  DEBUG=true
  DEBUGSEQ = true 
  def initialize (optsHash)
		@optsHash = optsHash
    setParameters()
  end

  def setParameters()
		@bedFile = @optsHash['--bedFile']
		@outFile = @optsHash['--outFile']
		@sample = @optsHash['--sample']
		@experiment = @optsHash['--experiment']
		@study = @optsHash['--study']
		if (@optsHash.key?('--tagSize')) then
			@tagSize = @optsHash['--tagSize'].to_i
			if (@tagSize<25 || @tagSize>200) then
				$stderr.puts "Tags size should be between 25 and 200"
				exit(2)
			end
		else
			@tagSize = 25
		end
  end

  def analyze()

		# run macs
		tmpMacsFile = "#{@outFile}.macs.tmp"
		macsCommand = "macs -t #{@bedFile} --name #{tmpMacsFile} --pvalue=0.0001 --tsize=#{@tagSize} 1>/dev/null 2>/dev/null"
		system(macsCommand)
		# generate output lff file
		macsVersion =`macs --version`

		r = File.open("#{tmpMacsFile}_peaks.xls", "r")
		w = File.open(@outFile, "w")
		l = nil
		cStart = 0
		cStop = 0
		cAdjust = 0
		chrom =  nil
		strand = nil
		val = nil
		fdr = nil
		r.each {|l|
			next if (l =~ /^#|tags/)
			ff = l.strip.split(/\t/)
			chrom = ff[0]
			cStart = ff[1].to_i
			cStop = ff[2].to_i
			score = ff[5]
			tags = score
			pval = Math::exp(ff[7].to_f/-10.0*Math::log(10))
			fdr = ff[8].to_f
			w.puts "#{@study}\t#{chrom}_#{cStart}_#{cStop}\t#{@experiment}\t#{@sample}\t#{chrom}\t#{cStart}\t#{cStop}\t+\t0\t#{score}\t.\t.\tfdr=#{fdr}; pval=#{pval}; software=MACS; version=#{macsVersion.strip}; params=\"--pvalue=0.0001\"; trackExtension=H2a1;"
		#	w.puts "#{chrom}\t#{cStart}\t#{cStop}\t#{chrom}_#{cStart}_#{cStop}\t+"
		}
		rmCmd = "/bin/rm -f #{tmpMacsFile}*"
		system(rmCmd)
		r.close()
		w.close()
	end


  def ChipSeqEDACCDriver.processArguments()
		# We want to add all the prop_keys as potential command line options
		optsArray =	[	['--bedFile', 			'-b', GetoptLong::REQUIRED_ARGUMENT],
									['--outFile', 			'-o', GetoptLong::REQUIRED_ARGUMENT],
									['--study', 				'-S', GetoptLong::REQUIRED_ARGUMENT],
									['--experiment', 		'-E', GetoptLong::REQUIRED_ARGUMENT],
									['--sample',	 			'-s', GetoptLong::REQUIRED_ARGUMENT],
									['--tagSize', 			'-t', GetoptLong::OPTIONAL_ARGUMENT],
									['--help', 					'-h', GetoptLong::NO_ARGUMENT]
								]
		progOpts = GetoptLong.new(*optsArray)
		optsHash = progOpts.to_hash
		ChipSeqEDACCDriver.usage() if(optsHash.key?('--help'));

		unless(progOpts.getMissingOptions().empty?)
			ChipSeqEDACCDriver.usage("USAGE ERROR: some required arguments are missing")
		end

		ChipSeqEDACCDriver.usage() if(optsHash.empty?);
		return optsHash
  end

  def ChipSeqEDACCDriver.usage(msg='')
    unless(msg.empty?)
      puts "\n#{msg}\n"
    end
    puts "
PROGRAM DESCRIPTION:
  Performs peak calling on a BED input file, and generates a Genboree Lff track
  according to the EDACC recommanedation document.

COMMAND LINE ARGUMENTS:
  --bedFile    |-b   => BED file containing uniquely mapping reads.
  --outFile    |-o   => output lff file
  --tagSize    |-t   => [optional] tag size (default 36)
  --study      |-S   => EDACC study
  --experiment |-E   => EDAC Experiment
  --sample     |-s   => EDACC Sample
  --help       |-h   => [optional flag] Output this usage info and exit

USAGE:
  chipSeqEDACCDriver.rb -b tags.bed -o peaks.lff -S Study1 -E Experiment1 -s Sample1
";
    exit(2);
	end
end


end
end

########  MAIN ##################
# Process command line options
optsHash = BRL::EDACC::ChipSeqEDACCDriver.processArguments()
# Instantiate analyzer using the program arguments
chipSeqAnalyzer = BRL::EDACC::ChipSeqEDACCDriver.new(optsHash)
# Analyze this !
chipSeqAnalyzer.analyze()
exit(0)
