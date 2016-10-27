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
      class CcdsGenes2lff
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
          @ccdsGeneFileName = optsHash.key?('--ccdsGeneFile') ? optsHash['--ccdsGeneFile'] : nil
          @ccdsKgMapFileName = optsHash.key?('--ccdsKgMapFile') ? optsHash['--ccdsKgMapFile'] : nil
          @knownGeneFileName = optsHash.key?('--knownGeneFile') ? optsHash['--knownGeneFile'] : nil
          @ccdsInfoFileName = optsHash.key?('--ccdsInfoFile') ? optsHash['--ccdsInfoFile'] : nil
          @knownToLocusLinkName = optsHash.key?('--knownToLocusLinkFile') ? optsHash['--knownToLocusLinkFile'] : nil
          @knownToRefSeqFileName = optsHash.key?('--knownToRefSeqFile') ? optsHash['--knownToRefSeqFile'] : nil
          @refFlatFileName = optsHash.key?('--refFlatFile') ? optsHash['--refFlatFile'] : nil
          @knownToEnsemblFileName = optsHash.key?('--knownToEnsemblFile') ? optsHash['--knownToEnsemblFile'] : nil
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
          allVariables["ccdsGeneFileName"] = @ccdsGeneFileName
          allVariables["ccdsKgMapFileName"] = @ccdsKgMapFileName
          allVariables["knownGeneFileName"] = @knownGeneFileName
          allVariables["ccdsInfoFileName"] = @ccdsInfoFileName
          allVariables["knownToLocusLinkName"] = @knownToLocusLinkName
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

          ccdsToccdsGeneTableHash = TableToHashCreator.ccdsToccdsGeneTableHash(@ccdsGeneFileName)
          ccdsToSwissProtHash = TableToHashCreator.ccdsToSwissProtHash(@ccdsKgMapFileName, @knownGeneFileName)
          ccdsTomRNAHash = TableToHashCreator.ccdsToNucAccHash(@ccdsInfoFileName)
          ccdsToProtHash = TableToHashCreator.ccdsToProtAccHash(@ccdsInfoFileName)
          ccdsTolocusLinkHash = TableToHashCreator.ccdsToLocusLinkHash(@ccdsKgMapFileName, @knownToLocusLinkName)
          ccdsToHugoNameHash = TableToHashCreator.ccdsToHugoNameHash(@ccdsInfoFileName, @knownToRefSeqFileName, @refFlatFileName, @knownToEnsemblFileName)
          ccdsToUcscGeneIdHash = TableToHashCreator.ccdsToKnownGeneIdHash(@ccdsKgMapFileName)

          ccdsToccdsGeneTableHash.each_key {|key|
            ccdsRecord = ccdsToccdsGeneTableHash[key]
            exons = ccdsRecord.exonEnds
            counter = 0
            exons.each {|exon|
              frame = ccdsRecord.exonFrames[exon].to_i
              if(frame == -1)
                exonFrame = "."
              else
                exonFrame = "#{frame}"
              end
              fileWriter.print "#{@outputClass}\t#{ccdsRecord.name}\t#{@outputType}\t#{@outputSubtype}\t#{ccdsRecord.chrom}\t"
              fileWriter.print "#{ccdsRecord.exonStarts[counter]}\t#{ccdsRecord.exonEnds[counter]}\t#{ccdsRecord.strand}\t#{exonFrame}\t0\t.\t.\t"
              fileWriter.print "txStart=#{ccdsRecord.txStart}; txEnd=#{ccdsRecord.txEnd}; "
              fileWriter.print "cdsStart=#{ccdsRecord.cdsStart}; cdsEnd=#{ccdsRecord.cdsEnd}; "
              fileWriter.print "exonCount=#{ccdsRecord.exonCount}; ccdsRecordId=#{ccdsRecord.iD}; "
              fileWriter.print "alternativeName=#{ccdsRecord.name2}; " if(!ccdsRecord.name2.nil?)
              fileWriter.print "ccdsName=#{ccdsRecord.name}; "
              swissProtAcc = TableToHashCreator.returnVPEntriesForHashOfHashes(ccdsToSwissProtHash, key, "swissProtAcc")
              fileWriter.print swissProtAcc if(!swissProtAcc.nil?)
              accNumbStr = TableToHashCreator.returnVPEntriesForHashOfHashes(ccdsTomRNAHash, key, "accNumb")
              fileWriter.print accNumbStr if(!accNumbStr.nil?)
              accProtStr = TableToHashCreator.returnVPEntriesForHashOfHashes(ccdsToProtHash, key, "proteinAcc")
              fileWriter.print accProtStr if(!accProtStr.nil?)
              ucscGeneId = TableToHashCreator.returnVPEntriesForHashOfHashes(ccdsToUcscGeneIdHash, key, "ucscGeneId")
              fileWriter.print ucscGeneId if(!ucscGeneId.nil?)
              locusLinkStr = TableToHashCreator.returnVPEntriesForHashOfHashes(ccdsTolocusLinkHash, key, "locusLinkId")
              fileWriter.print locusLinkStr if(!locusLinkStr.nil?)
              refSeqStr = TableToHashCreator.returnVPEntriesForHashOfHashes(ccdsToHugoNameHash, key, "refSeqId")
              fileWriter.print refSeqStr if(!refSeqStr.nil?)
              fileWriter.print "exonNum=#{counter + 1}; "
              fileWriter.print "cdsStartStatus=#{ccdsRecord.cdsStartStatus}; cdsEndStatus=#{ccdsRecord.cdsEndStatus};"
              fileWriter.puts ""
              counter = counter + 1
            }
          }
          fileWriter.close
        end

        def fetchFiles()
          return if(@doNotFtp)

          listOfFiles = Array.new()
          if(@ccdsGeneFileName.nil?)
            listOfFiles << "ccdsGene.txt.gz"
            @ccdsGeneFileName = "ccdsGene.txt.gz"
          end
          if(@ccdsInfoFileName.nil?)
            listOfFiles << "ccdsInfo.txt.gz"
            @ccdsInfoFileName = "ccdsInfo.txt.gz"
          end
          if(@ccdsKgMapFileName.nil?)
            listOfFiles << "ccdsKgMap.txt.gz"
            @ccdsKgMapFileName = "ccdsKgMap.txt.gz"
          end
          if(@refFlatFileName.nil?)
            listOfFiles << "refFlat.txt.gz"
            @refFlatFileName = "refFlat.txt.gz"
          end
          if(@knownGeneFileName.nil?)
            listOfFiles << "knownGene.txt.gz"
            @knownGeneFileName = "knownGene.txt.gz"
          end
          if(@knownToEnsemblFileName.nil?)
            listOfFiles << "knownToEnsembl.txt.gz"
            @knownToEnsemblFileName =  "knownToEnsembl.txt.gz"
          end
          if(@knownToLocusLinkName.nil?)
            listOfFiles << "knownToLocusLink.txt.gz"
            @knownToLocusLinkName = "knownToLocusLink.txt.gz"
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
        def CcdsGenes2lff.processArguments(outs)
          # We want to add all the prop_keys as potential command line options
          optsArray = [
            ['--nameOfOutputFile', '-o', GetoptLong::REQUIRED_ARGUMENT],
            ['--outputType', '-t', GetoptLong::REQUIRED_ARGUMENT],
            ['--outputSubtype', '-u', GetoptLong::REQUIRED_ARGUMENT],
            ['--outputClass', '-c', GetoptLong::REQUIRED_ARGUMENT],
            ['--localDirectory', '-d', GetoptLong::REQUIRED_ARGUMENT],
            ['--ccdsGeneFile', '-g', GetoptLong::OPTIONAL_ARGUMENT],
            ['--ccdsKgMapFile', '-l', GetoptLong::OPTIONAL_ARGUMENT],
            ['--ccdsInfoFile', '-e', GetoptLong::OPTIONAL_ARGUMENT],
            ['--knownGeneFile', '-a', GetoptLong::OPTIONAL_ARGUMENT],
            ['--knownToLocusLinkFile', '-f', GetoptLong::OPTIONAL_ARGUMENT],
            ['--knownToRefSeqFile', '-k', GetoptLong::OPTIONAL_ARGUMENT],
            ['--refFlatFile', '-b', GetoptLong::OPTIONAL_ARGUMENT],
            ['--knownToEnsemblFile', '-r', GetoptLong::OPTIONAL_ARGUMENT],
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
            CcdsGenes2lff.usage("USAGE ERROR: some required arguments are missing")
          end

          if(optsHash.empty? or optsHash.key?('--help'))
            CcdsGenes2lff.usage()
          end
          return optsHash
        end

        # Display usage info and quit.
        def CcdsGenes2lff.usage(msg='')
          unless(msg.empty?)
            $stderr.puts "\n#{msg}\n"
          end
          $stderr.puts "

                    PROGRAM DESCRIPTION:

                      Converts CcdsGenes table(s) from UCSC ccdsGene table to equivalent LFF version.

                      ccdsGene is a required table

                      Supports the following extra files from UCSC, which provide more
                      info about the gene or links to other databases:
          
                        ccdsGene
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
                          --ccdsGeneFile |  -g  =>  ccds Gene File
                          --ccdsKgMapFile |  -l  =>  ccdsKgMap File
                          --ccdsInfoFile |  -e  =>  ccdsInfo File
                          --knownGeneFile |  -a  =>  knownGene File
                          --knownToLocusLinkFile |  -f  =>  knownToLocusLink File
                          --knownToRefSeqFile |  -k  =>  knownToRefSeq File
                          --refFlatFile |  -b  =>  refFlat File
                          --knownToEnsemblFile |  -r  =>  knownToEnsembl File
                          --doNotFtp | -j =>  turn off autoFtp
                          --ucscDirectoryName |  -i  =>  ucsc directory name default /goldenPath/hg18/database

                          --verbose         | -V  => [Optional] Prints more error info (trace)
                                                and such when error. Mainly for Genboree.
                          --help            | -h  => [Optional flag]. Print help info and exit.
                    USAGE:
                    ccdsGenes2lff.rb -o outputFile -t type -u subtype -c genboree's class -d localDirectory to store and process files
                    ";
          exit(BRL::Genboree::USAGE_ERR);
        end # def CcdsGenes2lff.usage(msg='')

      end # class CcdsGenes2lff

    end; end; end #namespace

# ------------------------------------------------------------------------------

# ##############################################################################
# MAIN
# ##############################################################################
include BRL::FileFormats::UcscParsers

class CCDSGene2lff
  def initialize()
  end

  def main(optsHash)
    exitVal = 0
    outs = { :optsHash => nil, :verbose => false }
    
    $stderr.puts "#{Time.now()} ccdsGenes2lff - STARTING" if(outs[:verbose])

    # Instantiate method
    optsHash.each { | thekey, thevalue |
      $stderr.puts "the key #{thekey} --> with a value of #{thevalue}" if(outs[:verbose])
    }

    ccdsGenes2lff =  CcdsGenes2lff.new(optsHash)
    $stderr.puts "#{Time.now()} CcdsGenes2lff - INITIALIZED" if(outs[:verbose])
    exitVal = ccdsGenes2lff.execute()
    $stderr.puts "#{Time.now()} ccdsGenes2lff - FINISHED" if(outs[:verbose])
    $stderr.puts "#{Time.now()} Finishing the process" if(outs[:verbose])
    $stderr.puts "#{Time.now()} ccdsGenes2lff - DONE" if(exitVal == 0 and outs[:verbose])
  end
end

