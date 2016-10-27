#!/usr/bin/env ruby

# ##############################################################################
# LIBRARIES
# - The first 3 are standard for all apps.
# ##############################################################################
require 'brl/util/util'
require 'brl/genboree/genboreeUtil'
require 'brl/util/textFileUtil'
require 'brl/fileFormats/delimitedTable'

# ##############################################################################
# NAMESPACE
# - a.k.a. 'module'
# - This is standard and matches the directory location + "Tool"
# - //brl-depot/.../brl/genboree/toolPlugins/tools/HWcalculator/
# ##############################################################################
module BRL ; module Genboree ; module ToolPlugins ; module Tools ; module HWTool

	# ##############################################################################
	# HELPER CLASSES
	# ##############################################################################


	# ##############################################################################
	# EXECUTION CLASS
	# ##############################################################################
	class HWCalculator
		# Accessors (getters/setters ; instance variables
		attr_accessor :HWInFile, :desiredSNPId

	# Required: the "new()" equivalent
	def initialize(optsHash=nil)
		self.config(optsHash) unless(optsHash.nil?)
	end

	# ---------------------------------------------------------------
	# HELPER METHODS
	# - set up, do specific parts of the tool, etc
	# ---------------------------------------------------------------

	# Method to handle tool configuration/validation
	def config(optsHash)
		@HWInFile = optsHash['--HWFile'].strip
		@desiredSNPId = optsHash['--SNPId'].to_sym

		ff = File.open(@HWInFile)

		# Read in a delimited table from the file
		table = BRL::FileFormats::DelimitedTable.new(ff)

		#Hash to track all the GTs we've seen for the indicated SNP ID
		# - SNP ID assumed to be a column name in the sample file
		# - provide initialization block used to fill in missing keys with a
		#   default value
		@gtHash = Hash.new {|hh, kk| hh[kk] = 0 }

		table.each_row {|row|
			gtCall = row[@desiredSNPId]
			next unless(gtCall.to_s.size == 2) # skip things not looking like GTs
			@gtHash[gtCall.to_s] += 1 # increment the count for this GT call
		}

		# Track alleles using a Hash
		# - provide initialization block used to fill in missing keys with a
		#   default value
		@alleleHash = Hash.new {|hh,kk| hh[kk] = 0 }

		# Go through each GT and decompose it into its alleles
		@gtHash.each_key { |gt|
			alleles = gt.to_s.split(//) # Split on "nothing" == splits into Array of characters
		# Go through each character (allele) and add to allele hash
			alleles.each { |allele|
			@alleleHash[allele] += @gtHash[gt]
			}
		}
		end

		# hwcalculator
		def hwcalculator(homo1, hetero, homo2)
			n = homo1 + hetero + homo2
			freq_p = (((2 * homo1) + hetero).to_f / (2 * n))
			freq_q = (((2 * homo2) + hetero).to_f / (2 * n))
			exp_pp = freq_p * freq_p * n
			exp_pq = 2 * freq_p * freq_q * n
			exp_qq = freq_q * freq_q * n
			chi2_pp = (homo1 - exp_pp) * (homo1 - exp_pp)/ exp_pp
			chi2_pq = (hetero - exp_pq) * (hetero - exp_pq)/ exp_pq
			chi2_qq = (homo2 - exp_qq) * (homo2 - exp_qq)/ exp_qq
			chi2 = chi2_pp + chi2_pq + chi2_qq
			puts "Chi2", chi2
			if chi2 > 3.814
				puts "HWE out"
			else
				puts "HWE ok"
			end
		end

	# if different combination of two alleles: AT, GT, GA, CA, CT, CG then determine major
	# allele and minor allele
	def which_alleles (allele1, allele2, geno1, geno2a, geno2b, geno3)
		retVal = false
		if(@alleleHash.has_key?(allele1) && @alleleHash.has_key?(allele2))
			if(@alleleHash.fetch(allele1) > @alleleHash.fetch(allele2))
			p = @alleleHash[allele1]
			q =  @alleleHash[allele2]
			pp = @gtHash[geno1]
			pq = @gtHash[geno2a] + @gtHash[geno2b]
			qq = @gtHash[geno3]
			hwcalculator(pp, pq, qq)
			retVal = true
			elsif(@alleleHash.fetch(allele2) > @alleleHash.fetch(allele1))
			p = @alleleHash[allele2]
			q =  @alleleHash[allele1]
			pp = @gtHash[geno3]
			pq = @gtHash[geno2a] + @gtHash[geno2b]
			qq = @gtHash[geno1]
			hwcalculator(pp, pq, qq)
			retVal = true
			end
		end
		return retVal
	end

	# ---------------------------------------------------------------
	# MAIN EXECUTION METHOD
	# - instance method called to "do the tool"
	# ---------------------------------------------------------------

	#Need to test the keys of alleleHash to see if everything makes sense
	# - if only 1 key (1 allele) then monoallelic
	# - if >2 keys (>2 alleles) then multiallelic
	# - if SNPid data is not formatted correctly or the SNPid does not exist then error

	def HWAnnos()
		if(@alleleHash.size > 2)
			retVal=true
			puts ("seems to be tri or quad allelic")
		elsif(@alleleHash.size == 1)
			retVal=true
			puts ("seems to be mono allelic")
		elsif(which_alleles("A", "T", "AA", "AT", "TA", "TT"))
		elsif(which_alleles("G", "T", "GG", "GT", "TG", "GG"))
		elsif(which_alleles("G", "A", "GG", "GA", "AG", "AA"))
		elsif(which_alleles("A", "C", "AA", "AC", "CA", "CC"))
		elsif(which_alleles("C", "T", "CC", "CT", "TC", "TT"))
		elsif(which_alleles("G", "C", "GG", "GC", "CG", "CC"))
		else
			retVal=true
			puts("Genotype Not Found or
			Datafile Issue: Genotypes are not in correct
			format e.g. AA, AT, TT...")
		end
		return BRL:: Genboree::OK
	end

	# ---------------------------------------------------------------
	# CLASS METHODS
	# - generally just 2 (arg processor and usage)
	# ---------------------------------------------------------------
	# Process command-line args using POSIX standard

	def HWCalculator.processArguments()
	# We want to add all the prop_keys as potential command line options
		optsArray =[ ['--HWFile', '-w', GetoptLong::REQUIRED_ARGUMENT],
				['--SNPId', '-s', GetoptLong::REQUIRED_ARGUMENT],
				['--help', '-h', GetoptLong::NO_ARGUMENT]
				]
		progOpts = GetoptLong.new(*optsArray)
		HWCalculator.usage("USAGE ERROR: some required arguments are missing") unless(progOpts.getMissingOptions().empty?)
		optsHash = progOpts.to_hash
		HWCalculator.usage() if(optsHash.empty? or optsHash.key?('--help'));
		return optsHash
	end

	# Display usage info and quit.
	def HWCalculator.usage(msg='')
		unless(msg.empty?)
		puts "\n#{msg}\n"
	end
	puts"

	PROGRAM DESCRIPTION:

	Calculates Chi-square value between observed and expected genotypes consisting
	of two alleles. Then evaluates this statistic to determine if the SNP is in
	Hardy-Weinburg equilibrium. It also determines if the SNP has only one allele or
	3 or 4 alleles.

	Requires as inputs a datafile with the genotype counts in the form AA, AT, TT,
	GG, etc. and the SNPid to test Hardy-Weinburg equilibrium. Main output is rejection
	status of Hardy-Weinburg equilibrium for that SNPid.

	COMMAND LINE ARGUMENTS:

	--HWFile          | -w => Source genotype file.
	--desiredSNPId    | -s => Name of SNP to be tested.
	--help            | -h => [Optional flag]. Print help info and exit.

	USAGE:

	HWCalculator -w mydata.txt -s mysnp

	";

        exit(BRL::Genboree::USAGE_ERR);
	end # def HWCalculator.usage(msg='')
	end # class HWCalculator
	end ; end ; end ; end; end # namespace

# ##############################################################################
# MAIN
# ##############################################################################
  begin
    # Get arguments hash
    optsHash = BRL::Genboree::ToolPlugins::Tools::HWTool::HWCalculator.processArguments()
    $stderr.puts "#{Time.now()} HW - STARTING"
    # Instantiate method
    hw =  BRL::Genboree::ToolPlugins::Tools::HWTool::HWCalculator.new(optsHash)
    $stderr.puts "#{Time.now()} HW - INITIALIZED"
    # Execute tool
    exitVal = hw.HWAnnos()
  rescue Exception => err # Standard capture-log-report handling:
    errTitle =  "#{Time.now()} HW - FATAL ERROR: The HW calculator exited without processing all the data, due to a fatal error.\n"
    msgTitle =  "FATAL ERROR: The HW calculator exited without processing all the data, due to a fatal error.\nPlease contact the Genboree admin. This error has been dated and logged.\n"
    errstr   =  "   The error message was: '#{err.message}'.\n"
    errstr   += "   The complete back-trace is:\n\"\n" + err.backtrace.join("\n") + "\n\""
    puts msgTitle
    $stderr.puts errTitle + errstr
    exitVal = BRL::Genboree::FATAL
  end
  $stderr.puts "#{Time.now()} HW - DONE" unless(exitVal != 0)
  exit(exitVal)
