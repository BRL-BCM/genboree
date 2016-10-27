#!/usr/bin/env ruby
$VERBOSE = nil

# ##############################################################################
# PURPOSE
# ##############################################################################
# Simple: convert from UCSC knownGene table to equivalent LFF version

# ##############################################################################
# REQUIRED LIBRARIES
# ##############################################################################
require 'brl/util/textFileUtil'
require 'brl/util/util'
require 'brl/util/propTable' # for PropTable class

require 'brl/fileFormats/ucscParsers/tableToHashCreator'
require 'brl/fileFormats/ucscParsers/ucscTables'
require 'net/ftp'
require 'brl/net/fetchFromFTP'

# ##############################################################################
# CONSTANTS
# ##############################################################################
GZIP = BRL::Util::TextWriter::GZIP_OUT

# ##############################################################################
# HELPER FUNCTIONS
# ##############################################################################
# Process command line args
# Note:
#      - extra alias files are optional, but clearly should be provided

module BRL ; module FileFormats; module UcscParsers
      class EnsemblGenes2lff
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
          @outputFile = optsHash['--nameOfOutputFile'].strip
          @outputType = optsHash.key?('--outputSubtype') ? optsHash['--outputType'].gsub(/\\/,'').gsub(/\\,/, ',').gsub(/\\"/, "'") : "gene"
          @outputSubtype = optsHash.key?('--outputSubtype') ? optsHash['--outputSubtype'].gsub(/\\/,'').gsub(/\\,/, ',').gsub(/\\"/, "'") : "Models"
          @outputClass = optsHash.key?('--outputClass') ? optsHash['--outputClass'].gsub(/\\/,'').gsub(/\\,/, ',').gsub(/\\"/, "'") : "02. Unified Gene Model"
          @localDirectory =  optsHash['--localDirectory'].strip
          @ucscDirectoryName = optsHash.key?('--ucscDirectoryName') ? optsHash['--ucscDirectoryName'] : "/goldenPath/hg18/database"
          @ensGeneFileName = optsHash.key?('--ensGeneFileName') ? optsHash['--ensGeneFileName'] : nil
          @ensGtpFileName = optsHash.key?('--ensGtpFileName') ? optsHash['--ensGtpFileName'] : nil
          @ensPepFileName = optsHash.key?('--ensPepFileName') ? optsHash['--ensPepFileName'] : nil
          @sfDescriptionFileName = optsHash.key?('--sfDescriptionFileName') ? optsHash['--sfDescriptionFileName'] : nil
          @superfamilyFileName = optsHash.key?('--superfamilyFileName') ? optsHash['--superfamilyFileName'] : nil
          @ccdsInfoFileName = optsHash.key?('--ccdsInfoFileName') ? optsHash['--ccdsInfoFileName'] : nil
          @knownToLocusLinkFileName = optsHash.key?('--knownToLocusLinkFileName') ? optsHash['--knownToLocusLinkFileName'] : nil
          @knownToRefSeqFileName = optsHash.key?('--knownToRefSeqFileName') ? optsHash['--knownToRefSeqFileName'] : nil
          @refFlatFileName = optsHash.key?('--refFlatFileName') ? optsHash['--refFlatFileName'] : nil
          @knownToEnsemblFileName = optsHash.key?('--knownToEnsemblFileName') ? optsHash['--knownToEnsemblFileName'] : nil
          @verboseOn = optsHash.has_key?('--verbose')
          @doNotFtp = optsHash.has_key?('--doNotFtp')
          $stderr.puts "the @outputType @outputSubtype @outputClass\nand the @verboseOn = #{@verboseOn}" if(@verboseOn)
        end

        def printVariables()
          allVariables = {}
          allVariables["outputFile"] = @outputFile
          allVariables["outputType"] = @outputType
          allVariables["outputSubtype"] = @outputSubtype
          allVariables["outputClass"] = @outputClass
          allVariables["localDirectory"] = @localDirectory
          allVariables["ucscDirectoryName"] = @ucscDirectoryName
          allVariables["ensGeneFileName"] = @ensGeneFileName
          allVariables["ensGtpFileName"] = @ensGtpFileName
          allVariables["ensPepFileName"] = @ensPepFileName
          allVariables["sfDescriptionFileName"] = @sfDescriptionFileName
          allVariables["superfamilyFileName"] = @superfamilyFileName
          allVariables["ccdsInfoFileName"] = @ccdsInfoFileName
          allVariables["knownToLocusLinkFileName"] = @knownToLocusLinkFileName
          allVariables["knownToRefSeqFileName"] = @knownToRefSeqFileName
          allVariables["refFlatFileName"] = @refFlatFileName
          allVariables["knownToEnsemblFileName"] = @knownToEnsemblFileName
          allVariables["verboseOn"] = @verboseOn
          allVariables["doNotFtp"] = @doNotFtp
          if(@verboseOn)
            allVariables.each {|key, value|
              $stderr.puts "#{key} = #{value}"
            }
          end

        end

        # ---------------------------------------------------------------
        # MAIN EXECUTION METHOD
        # - instance method called to
        # ---------------------------------------------------------------
        # Applies rules to each record in LFF file and outputs LFF record accordingly.

        def runParser()
          fileWriter = BRL::Util::TextWriter.new(@outputFile)

          ensGenTableHash = TableToHashCreator.ensToEnsGeneTableHash(@ensGeneFileName)
          ensembl2ccdsHash = TableToHashCreator.nucAccToCcdsHash(@ccdsInfoFileName)
          ensembl2protAccHash = TableToHashCreator.nucAccToProtAcc(@ccdsInfoFileName)
          ensemblToHugoNameHash = TableToHashCreator.createEnsemblToHugoNameHash(@knownToRefSeqFileName, @refFlatFileName, @knownToEnsemblFileName)
          ensemblToKnownHash = TableToHashCreator.valueToNameRawHash(@knownToEnsemblFileName)
          ensemblToLocusLinkHash =  TableToHashCreator.ensemblToLocusLinkHash(@knownToEnsemblFileName, @knownToLocusLinkFileName)
          ensemblTrans2GeneNameHash =  TableToHashCreator.ensemblTranscriptToensembleGeneName(@ensGtpFileName)
          ensemblTrans2ProteinNameHash =  TableToHashCreator.ensemblTranscriptToensembleProteinName(@ensGtpFileName)

          ensGenTableHash.each_key {|key|
            ensemblRecord = ensGenTableHash[key]
            exons = ensemblRecord.exonEnds
            counter = 0
            exons.each {|exon|
              exonFrame = "0"
              fileWriter.print "#{@outputClass}\t#{ensemblRecord.name}\t#{@outputType}\t#{@outputSubtype}\t#{ensemblRecord.chrom}\t"
              fileWriter.print "#{ensemblRecord.exonStarts[counter]}\t#{ensemblRecord.exonEnds[counter]}\t#{ensemblRecord.strand}\t#{exonFrame}\t0\t.\t.\t"
              fileWriter.print "txStart=#{ensemblRecord.txStart}; txEnd=#{ensemblRecord.txEnd}; "
              fileWriter.print "cdsStart=#{ensemblRecord.cdsStart}; cdsEnd=#{ensemblRecord.cdsEnd}; "
              fileWriter.print "exonCount=#{ensemblRecord.exonCount}; ensemblTransName=#{ensemblRecord.name}; "
              ccdsAcc = TableToHashCreator.returnVPEntriesForHashOfHashes(ensembl2ccdsHash, key, "ccdsName")
              fileWriter.print ccdsAcc if(!ccdsAcc.nil?)
              refSeqStr = TableToHashCreator.returnVPEntriesForHashOfHashes(ensemblToHugoNameHash, key, "refSeqId")
              fileWriter.print refSeqStr if(!refSeqStr.nil?)
              accProtStr = TableToHashCreator.returnVPEntriesForHashOfHashes(ensembl2protAccHash, key, "proteinAcc")
              fileWriter.print accProtStr if(!accProtStr.nil?)
              ucscGeneId = TableToHashCreator.returnVPEntriesForHashOfHashes(ensemblToKnownHash, key, "ucscGeneId")
              fileWriter.print ucscGeneId if(!ucscGeneId.nil?)
              locusLinkStr = TableToHashCreator.returnVPEntriesForHashOfHashes(ensemblToLocusLinkHash, key, "locusLinkId")
              fileWriter.print locusLinkStr if(!locusLinkStr.nil?)
              ensemblGeneNameStr = TableToHashCreator.returnVPEntriesForHashOfHashes(ensemblTrans2GeneNameHash, key, "ensemblGeneName")
              fileWriter.print ensemblGeneNameStr if(!ensemblGeneNameStr.nil?)
              ensemblProteinNameStr = TableToHashCreator.returnVPEntriesForHashOfHashes(ensemblTrans2ProteinNameHash, key, "ensemblProtName")
              fileWriter.print ensemblProteinNameStr if(!ensemblProteinNameStr.nil?)

              fileWriter.print "exonNum=#{counter + 1}; "
              fileWriter.puts ""
              counter = counter + 1
            }
          }
          fileWriter.close
        end

        def fetchFiles()
          return if(@doNotFtp)

          listOfFiles = Array.new()
          if(@ensGeneFileName.nil?)
            listOfFiles << "ensGene.txt.gz"
            @ensGeneFileName = "ensGene.txt.gz"
          end
          if(@ccdsInfoFileName.nil?)
            listOfFiles << "ccdsInfo.txt.gz"
            @ccdsInfoFileName = "ccdsInfo.txt.gz"
          end
          if(@ensGtpFileName.nil?)
            listOfFiles << "ensGtp.txt.gz"
            @ensGtpFileName = "ensGtp.txt.gz"
          end
          if(@sfDescriptionFileName.nil?)
            listOfFiles << "sfDescription.txt.gz"
            @sfDescriptionFileName = "sfDescription.txt.gz"
          end
          if(@refFlatFileName.nil?)
            listOfFiles << "refFlat.txt.gz"
            @refFlatFileName = "refFlat.txt.gz"
          end
          if(@superfamilyFileName.nil?)
            listOfFiles << "superfamily.txt.gz"
            @superfamilyFileName = "superfamily.txt.gz"
          end
          if(@knownToEnsemblFileName.nil?)
            listOfFiles << "knownToEnsembl.txt.gz"
            @knownToEnsemblFileName =  "knownToEnsembl.txt.gz"
          end
          if(@ensPepFileName.nil?)
            listOfFiles << "ensPep.txt.gz"
            @ensPepFileName =  "ensPep.txt.gz"
          end
          if(@knownToLocusLinkFileName.nil?)
            listOfFiles << "knownToLocusLink.txt.gz"
            @knownToLocusLinkFileName = "knownToLocusLink.txt.gz"
          end
          if(@knownToRefSeqFileName.nil?)
            listOfFiles << "knownToRefSeq.txt.gz"
            @knownToRefSeqFileName = "knownToRefSeq.txt.gz"
          end

          fetch = BRL::Net::FetchFromFTP.new("hgdownload.cse.ucsc.edu", @ucscDirectoryName)
          fetch.getAllTextFilesInArray(@localDirectory, listOfFiles)
        end

        def execute()
          fetchFiles()
          printVariables()
          runParser()
          return 0
        end

        # ---------------------------------------------------------------
        # CLASS METHODS
        # - generally just 2 (arg processor and usage)
        # ---------------------------------------------------------------
        # Process command-line args using POSIX standard
        def EnsemblGenes2lff.processArguments(outs)
          # We want to add all the prop_keys as potential command line options

          optsArray = [
            ['--nameOfOutputFile', '-o', GetoptLong::REQUIRED_ARGUMENT],
            ['--outputType', '-t', GetoptLong::REQUIRED_ARGUMENT],
            ['--outputSubtype', '-u', GetoptLong::REQUIRED_ARGUMENT],
            ['--outputClass', '-c', GetoptLong::REQUIRED_ARGUMENT],
            ['--localDirectory', '-d', GetoptLong::REQUIRED_ARGUMENT],
            ['--ensGeneFileName', '-y', GetoptLong::OPTIONAL_ARGUMENT],
            ['--ensGtpFileName', '-z', GetoptLong::OPTIONAL_ARGUMENT],
            ['--ensPepFileName', '-g', GetoptLong::OPTIONAL_ARGUMENT],
            ['--sfDescriptionFileName', '-l', GetoptLong::OPTIONAL_ARGUMENT],
            ['--superfamilyFileName', '-a', GetoptLong::OPTIONAL_ARGUMENT],
            ['--ccdsInfoFileName', '-e', GetoptLong::OPTIONAL_ARGUMENT],
            ['--knownToLocusLinkFileName', '-f', GetoptLong::OPTIONAL_ARGUMENT],
            ['--knownToRefSeqFileName', '-k', GetoptLong::OPTIONAL_ARGUMENT],
            ['--refFlatFileName', '-b', GetoptLong::OPTIONAL_ARGUMENT],
            ['--knownToEnsemblFileName', '-r', GetoptLong::OPTIONAL_ARGUMENT],
            ['--ucscDirectoryName', '-i', GetoptLong::OPTIONAL_ARGUMENT],
            ['--doNotFtp', '-j', GetoptLong::OPTIONAL_ARGUMENT],
            ['--verbose', '-V', GetoptLong::NO_ARGUMENT],
            ['--help', '-h', GetoptLong::NO_ARGUMENT]
          ]
          progOpts = GetoptLong.new(*optsArray)
          optsHash = progOpts.to_hash
          outs[:verbose] = true if(optsHash and optsHash.key?('--verbose'))
          outs[:optsHash] = optsHash
          unless(progOpts.getMissingOptions().empty?)
            @@usageError = true
            EnsemblGenes2lff.usage("USAGE ERROR: some required arguments are missing")
          end

          if(optsHash.empty? or optsHash.key?('--help'))
            EnsemblGenes2lff.usage()
          end
          return optsHash
        end

        # Display usage info and quit.
        def EnsemblGenes2lff.usage(msg='')
          unless(msg.empty?)
            $stderr.puts "\n#{msg}\n"
          end
          $stderr.puts "

                    PROGRAM DESCRIPTION:

                      Converts CcdsGenes table(s) from UCSC ccdsGene table to equivalent LFF version.

                      ccdsGene is a required table

                      Supports the following extra files from UCSC, which provide more
                      info about the gene or links to other databases:

                        ccdsKgMap
                        ccdsInfo
                        knownToEnsembl
                        knownToRefSeq
                        knownGene
                        knownToLocusLink
                        refFlat

                      These files are optional and may not be available for all species.
                      However, if available they should be downloaded and used!
                      Important Note: This program was developed using Hg18 databases, it has not been tested
                      for othere species. The program automatically retrieve the files unless you
                      provide the files with the specific tag or you disable the ftp support

                    COMMAND LINE ARGUMENTS:
                          --nameOfOutputFile   | -o  =>  Name of output file
                          --outputType      | -t  => The output track's 'gene'.
                          --outputSubtype   | -u  => The output track's 'ccds'.
                          --outputClass     | -c  => [Optional] The output track's 'class'.
                                                     Defaults to 'Gene'.
                          --localDirectory |  -d  =>  Name of local directory required
                          --ensGeneFileName |  -y  =>  ensemble Gene File
                          --ensGtpFileName |  -z  =>  ensGtp File
                          --ensPepFileName |  -g  =>  ensPep File
                          --sfDescriptionFileName |  -l  =>  sfDescription File
                          --superfamilyFileName |  -a  =>  superfamily File
                          --ccdsInfoFile |  -e  =>  ccdsInfo File
                          --knownToLocusLinkFileName |  -f  =>  knownToLocusLink File
                          --knownToRefSeqFileName |  -k  =>  knownToRefSeq File
                          --refFlatFileName |  -b  =>  refFlat File
                          --knownToEnsemblFileName |  -r  =>  knownToEnsembl File
                          --doNotFtp | -j =>  turn off autoFtp
                          --ucscDirectoryName |  -i  =>  ucsc directory name default /goldenPath/hg18/database

                          --verbose         | -V  => [Optional] Prints more error info (trace)
                                                and such when error. Mainly for Genboree.
                          --help            | -h  => [Optional flag]. Print help info and exit.
                    USAGE:
                    ensemblGenes2lff.rb -o outputFile -t type -u subtype -c genboree's class -d localDirectory to store and process files
                    ";
          exit(BRL::Genboree::USAGE_ERR);
        end # def EnsemblGenes2lff.usage(msg='')

      end # class EnsemblGenes2lff

    end; end; end #namespace

# ------------------------------------------------------------------------------

# ##############################################################################
# MAIN
# ##############################################################################
include BRL::FileFormats::UcscParsers

class EnsembleGene2lff
  def initialize()
  end

  def main(optsHash)
    outs = { :optsHash => nil, :verbose => false }

    $stderr.puts "#{Time.now()} ensemblGenes2lff - STARTING" if(outs[:verbose])

    # Instantiate method
    optsHash.each { | thekey, thevalue |
      $stderr.puts "the key #{thekey} --> with a value of #{thevalue}" if(outs[:verbose])
    }

    ensemblGenes2lff =  EnsemblGenes2lff.new(optsHash)
    $stderr.puts "#{Time.now()} EnsemblGenes2lff - INITIALIZED" if(outs[:verbose])
    exitVal = ensemblGenes2lff.execute()
    $stderr.puts "#{Time.now()} ensemblGenes2lff - FINISHED" if(outs[:verbose])
    $stderr.puts "#{Time.now()} Finishing the process" if(outs[:verbose])
    $stderr.puts "#{Time.now()} ensemblGenes2lff - DONE" if(exitVal == 0 and outs[:verbose])
  end
end