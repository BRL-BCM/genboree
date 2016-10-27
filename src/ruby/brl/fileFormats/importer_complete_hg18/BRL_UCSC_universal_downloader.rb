#!/usr/bin/env ruby
##################### No warning!
$VERBOSE = nil

# ###################################################################################################################################
# Program: A downloader which can download the files from UCSC given info about the external host, the path, the requested file list, etc. 
# from command line parameters

# ##################################################################################################################################
# REQUIRED LIBRARIES
# ##############################################################################
require 'brl/util/textFileUtil'
require 'brl/util/util'
require 'brl/genboree/genboreeUtil'
require 'net/ftp'
require 'timeout'

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
# Process command line args
# Note:
#      - did not find optional extra alias files
def processArguments()
  optsArray = [
                ['--hostFile', '-o', GetoptLong::REQUIRED_ARGUMENT],
                ['--assemblyName', '-a', GetoptLong::REQUIRED_ARGUMENT],
                ['--fileName', '-f', GetoptLong::REQUIRED_ARGUMENT],
                ['--dDirectoryOutput', '-d', GetoptLong::REQUIRED_ARGUMENT],
                ['--emailAddress', '-e', GetoptLong::REQUIRED_ARGUMENT],
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
    usage("Error:the REQUIRED args are missing!")
    exit(USAGE_ERR)
  else
    return optsHash
  end
end

def usage(msg='')
  puts "\n#{msg}\n" unless(msg.empty?)
  puts "

PROGRAM DESCRIPTION:
  Download requested source file(s) given a particular assembly version of a species available from UCSC.

  COMMAND LINE ARGUMENTS:
    --hostFile              | -o    => UCSC host address to contact
    --assemblyName          | -a    => Assembly version to download
    --fileName              | -f    => File name to download
    --dDirectoryOutput      | -d    => The directory where downloaded files should go
    --emailAddress          | -e    => Email address to provide
    --help                  | -h   => [optional flag] Output this usage
                                      info and exit.

  USAGE: ruby BRL_UCSC_downloader.rb -o host -a assembly_for_a_species -f fileList -d directoryOutputFileGo -e email_address
  i.e. 
Human:
ruby BRL_UCSC_downloader.rb -o hgdownload.cse.ucsc.edu -a hg18 -f fosEndPairs.txt.gz -d /users/ybai/work/Project1/test_Downloader -e ybai@ws59.hgsc.bcm.tmc.edu
ruby BRL_UCSC_downloader.rb -o hgdownload.cse.ucsc.edu -a hg18 -f chr*_chainPanTro2.txt.gz -d /users/ybai/work/Project1/test_Downloader -e ybai@ws59.hgsc.bcm.tmc.edu
ruby BRL_UCSC_downloader.rb -o hgdownload.cse.ucsc.edu -a hg18 -f hapmap*.txt.gz -d /users/ybai/work/Project4/HapMap_SNPs/ -e ybai@ws59.hgsc.bcm.tmc.edu
ruby BRL_UCSC_downloader.rb -o hgdownload.cse.ucsc.edu -a hg18 -f cnpIafrate2.txt.gz -d /users/ybai/work/Structural_Variants/converter_cnpIafrate2/ -e ybai@ws59.hgsc.bcm.tmc.edu
ruby BRL_UCSC_downloader.rb -o hgdownload.cse.ucsc.edu -a hg18 -f cnpLocke.txt.gz -d /users/ybai/work/Structural_Variants/converter_cnpLocke/ -e ybai@ws59.hgsc.bcm.tmc.edu
ruby BRL_UCSC_downloader.rb -o hgdownload.cse.ucsc.edu -a hg18 -f cnpRedon.txt.gz -d /users/ybai/work/Structural_Variants/converter_cnpRedon_new/ -e ybai@ws59.hgsc.bcm.tmc.edu
ruby BRL_UCSC_downloader.rb -o hgdownload.cse.ucsc.edu -a hg18 -f cnpSebat2.txt.gz -d /users/ybai/work/Structural_Variants/converter_cnpSebat2_new/ -e ybai@ws59.hgsc.bcm.tmc.edu
ruby BRL_UCSC_downloader.rb -o hgdownload.cse.ucsc.edu -a hg18 -f cnpSharp2.txt.gz -d /users/ybai/work/Structural_Variants/converter_cnpSharp2/ -e ybai@ws59.hgsc.bcm.tmc.edu
ruby BRL_UCSC_downloader.rb -o hgdownload.cse.ucsc.edu -a hg18 -f cnpTuzun.txt.gz -d /users/ybai/work/Structural_Variants/converter_cnpTuzun_new/ -e ybai@ws59.hgsc.bcm.tmc.edu
ruby BRL_UCSC_downloader.rb -o hgdownload.cse.ucsc.edu -a hg18 -f delConrad2.txt.gz -d /users/ybai/work/Structural_Variants/converter_delConrad2_new/ -e ybai@ws59.hgsc.bcm.tmc.edu
ruby BRL_UCSC_downloader.rb -o hgdownload.cse.ucsc.edu -a hg18 -f delHinds2.txt.gz -d /users/ybai/work/Structural_Variants/converter_delHinds2_new/ -e ybai@ws59.hgsc.bcm.tmc.edu
ruby BRL_UCSC_downloader.rb -o hgdownload.cse.ucsc.edu -a hg18 -f delMccarroll.txt.gz -d /users/ybai/work/Structural_Variants/converter_delMccarroll_new/ -e ybai@ws59.hgsc.bcm.tmc.edu
ruby BRL_UCSC_downloader.rb -o hgdownload.cse.ucsc.edu -a hg18 -f *.hg18.* -d /users/ybai/work/Variants_TCAG/ -e ybai@ws59.hgsc.bcm.tmc.edu
ruby BRL_UCSC_downloader.rb -o hgdownload.cse.ucsc.edu -a hg18 -f cccTrendPval*.txt.gz -d /users/ybai/work/Project3/DIS_CCC/ -e ybai@ws59.hgsc.bcm.tmc.edu
ruby BRL_UCSC_downloader.rb -o hgdownload.cse.ucsc.edu -a hg18 -f gad.txt.gz -d /users/ybai/work/Project3/DIS_GAD/ -e ybai@ws59.hgsc.bcm.tmc.edu
ruby BRL_UCSC_downloader.rb -o hgdownload.cse.ucsc.edu -a hg18 -f nimhBipolar*.txt.gz -d /users/ybai/work/Project3/NIMH_BIPOLAR/ -e ybai@ws59.hgsc.bcm.tmc.edu
ruby BRL_UCSC_downloader.rb -o hgdownload.cse.ucsc.edu -a hg18 -f rgdQtl*.txt.gz -d /users/ybai/work/Project3/RGD_QTL/ -e ybai@ws59.hgsc.bcm.tmc.edu
ruby BRL_UCSC_downloader.rb -o hgdownload.cse.ucsc.edu -a hg18 -f knownGene.txt.gz -d users/ybai/work/Project4/UCSC_Genes/ -e ybai@ws59.hgsc.bcm.tmc.edu
ruby BRL_UCSC_downloader.rb -o hgdownload.cse.ucsc.edu -a hg18 -f bacEndPairs.txt.gz -d /users/ybai/work/Human_Project5/BAC_EndPairs/ -e ybai@ws59.hgsc.bcm.tmc.edu
ruby BRL_UCSC_downloader.rb -o hgdownload.cse.ucsc.edu -a hg18 -f microsat.txt.gz -d /users/ybai/work/Human_Project5/Microsatellites/ -e ybai@ws59.hgsc.bcm.tmc.edu
ruby BRL_UCSC_downloader.rb -o hgdownload.cse.ucsc.edu -a hg18 -f simpleRepeat.txt.gz -d /users/ybai/work/Human_Project5/Simple_Repeats/ -e ybai@ws59.hgsc.bcm.tmc.edu
ruby BRL_UCSC_downloader.rb -o hgdownload.cse.ucsc.edu -a hg18 -f wgRna.txt.gz -d /users/ybai/work/Human_sno-miRNA/ -e ybai@ws59.hgsc.bcm.tmc.edu
ruby BRL_UCSC_downloader.rb -o hgdownload.cse.ucsc.edu -a hg18 -f snp128.txt.gz -d /users/ybai/work/Project4/SNPs_128/ -e ybai@ws59.hgsc.bcm.tmc.edu
ruby BRL_UCSC_downloader.rb -o hgdownload.cse.ucsc.edu -a hg18 -f affyGnf1h.txt.gz -d /users/ybai/work/Human_Project6/Expression_Regulation/Affy_GNF1H/ -e ybai@ws59.hgsc.bcm.tmc.edu
ruby BRL_UCSC_downloader.rb -o hgdownload.cse.ucsc.edu -a hg18 -f affyHuEx1.txt.gz -d /users/ybai/work/Human_Project6/Expression_Regulation/Affy_HuEx/ -e ybai@ws59.hgsc.bcm.tmc.edu
ruby BRL_UCSC_downloader.rb -o hgdownload.cse.ucsc.edu -a hg18 -f affyU95.txt.gz -d /users/ybai/work/Human_Project6/Expression_Regulation/Affy_U95/ -e ybai@ws59.hgsc.bcm.tmc.edu
ruby BRL_UCSC_downloader.rb -o hgdownload.cse.ucsc.edu -a hg18 -f gnfAtlas2.txt.gz -d /users/ybai/work/Human_Project6/Expression_Regulation/GNF_Atlas2/ -e ybai@ws59.hgsc.bcm.tmc.edu
ruby BRL_UCSC_downloader.rb -o hgdownload.cse.ucsc.edu -a hg18 -f affyU133.txt.gz -d /users/ybai/work/Human_Project6/Expression_Regulation/Affy_U133/ -e ybai@ws59.hgsc.bcm.tmc.edu
ruby BRL_UCSC_downloader.rb -o hgdownload.cse.ucsc.edu -a hg18 -f affyU133Plus2.txt.gz -d /users/ybai/work/Human_Project6/Expression_Regulation/Affy_U133Plus2/ -e ybai@ws59.hgsc.bcm.tmc.edu
ruby BRL_UCSC_downloader.rb -o hgdownload.cse.ucsc.edu -a hg18 -f hapmapLd*.txt.gz -d /users/ybai/work/Human_Project6/Variation_Repeats/HapMap_LD/ -e ybai@ws59.hgsc.bcm.tmc.edu
ruby BRL_UCSC_downloader.rb -o hgdownload.cse.ucsc.edu -a hg18 -f genomicSuperDups.txt.gz -d /users/ybai/work/Human_Project6/Variation_Repeats/Segmental_Dups/ -e ybai@ws59.hgsc.bcm.tmc.edu
ruby BRL_UCSC_downloader.rb -o hgdownload.cse.ucsc.edu -a hg18 -f *_rmsk.txt.gz -d /users/ybai/work/Human_Project5/Repeat_Masker -e ybai@ws59.hgsc.bcm.tmc.edu
ruby BRL_UCSC_downloader.rb -o hgdownload.cse.ucsc.edu -a hg18 -f *_est.txt.gz -d /users/ybai/work/Human_Project6/mRNA_EST/All_EST -e ybai@ws59.hgsc.bcm.tmc.edu
ruby BRL_UCSC_downloader.rb -o hgdownload.cse.ucsc.edu -a hg18 -f *_mrna.txt.gz -d /users/ybai/work/Human_Project6/mRNA_EST/All_mRNA -e ybai@ws59.hgsc.bcm.tmc.edu
ruby BRL_UCSC_downloader.rb -o hgdownload.cse.ucsc.edu -a hg18 -f *_intronEst.txt.gz -d /users/ybai/work/Human_Project6/mRNA_EST/Spliced_EST -e ybai@ws59.hgsc.bcm.tmc.edu
ruby BRL_UCSC_downloader.rb -o hgdownload.cse.ucsc.edu -a hg18 -f xenoEst.txt.gz -d /users/ybai/work/Human_Project6/mRNA_EST/Other_EST -e ybai@ws59.hgsc.bcm.tmc.edu
ruby BRL_UCSC_downloader.rb -o hgdownload.cse.ucsc.edu -a hg18 -f uniGene_3.txt.gz -d /users/ybai/work/Human_Project6/mRNA_EST/Uni_Gene -e ybai@ws59.hgsc.bcm.tmc.edu
ruby BRL_UCSC_downloader.rb -o hgdownload.cse.ucsc.edu -a hg18 -f jaxQtl*.gz -d /users/ybai/work/Project3/MGI_MOUSE_QTL -e ybai@ws59.hgsc.bcm.tmc.edu
ruby BRL_UCSC_downloader.rb -o hgdownload.cse.ucsc.edu -a hg18 -f rgdRatQtl*.gz -d /users/ybai/work/Project3/RGD_RAT_QTL -e ybai@ws59.hgsc.bcm.tmc.edu
ruby BRL_UCSC_downloader.rb -o hgdownload.cse.ucsc.edu -a hg17 -f snp125.txt.gz -d /users/ybai/work/Project4/SNPs_hg17/ -e ybai@ws59.hgsc.bcm.tmc.edu
ruby BRL_UCSC_downloader.rb -o hgdownload.cse.ucsc.edu -a hg16 -f snp.txt.gz -d /users/ybai/work/Project4/SNPs_hg16/ -e ybai@ws59.hgsc.bcm.tmc.edu
ruby BRL_UCSC_downloader.rb -o hgdownload.cse.ucsc.edu -a hg16 -f miRNA.txt.gz -d /users/ybai/work/Human_hg16-miRNA/ -e ybai@ws59.hgsc.bcm.tmc.edu
ruby BRL_UCSC_downloader.rb -o hgdownload.cse.ucsc.edu -a hg15 -f rnaGene.txt.gz -d /users/ybai/work/Human_hg15-miRNA/ -e ybai@ws59.hgsc.bcm.tmc.edu

Mouse:
ruby BRL_UCSC_downloader.rb -o hgdownload.cse.ucsc.edu -a mm9 -f snp128.txt.gz -d /users/ybai/work/Project5/SNP128/ -e ybai@ws59.hgsc.bcm.tmc.edu
ruby BRL_UCSC_downloader.rb -o hgdownload.cse.ucsc.edu -a mm9 -f knownGene.txt.gz -d /users/ybai/work/Mouse_Project4/UCSC_Genes/ -e ybai@ws59.hgsc.bcm.tmc.edu
ruby BRL_UCSC_downloader.rb -o hgdownload.cse.ucsc.edu -a mm9 -f bacEndPairs.txt.gz -d /users/ybai/work/Project5/BAC_EndPairs/ -e ybai@ws59.hgsc.bcm.tmc.edu
ruby BRL_UCSC_downloader.rb -o hgdownload.cse.ucsc.edu -a mm9 -f microsat.txt.gz -d /users/ybai/work/Project5/Microsatellites/ -e ybai@ws59.hgsc.bcm.tmc.edu
ruby BRL_UCSC_downloader.rb -o hgdownload.cse.ucsc.edu -a mm9 -f chr*_rmsk.txt.gz -d /users/ybai/work/Project5/Repeat_Masker/ -e ybai@ws59.hgsc.bcm.tmc.edu
ruby BRL_UCSC_downloader.rb -o hgdownload.cse.ucsc.edu -a mm9 -f simpleRepeat.txt.gz -d /users/ybai/work/Project5/Simple_Repeats/ -e ybai@ws59.hgsc.bcm.tmc.edu
ruby BRL_UCSC_downloader.rb -o hgdownload.cse.ucsc.edu -a mm9 -f chr*_est.txt.gz -d /users/ybai/work/Project6/mRNA_EST/All_EST/ -e ybai@ws59.hgsc.bcm.tmc.edu
ruby BRL_UCSC_downloader.rb -o hgdownload.cse.ucsc.edu -a mm9 -f chr*_mrna.txt.gz -d /users/ybai/work/Project6/mRNA_EST/All_mRNA/ -e ybai@ws59.hgsc.bcm.tmc.edu
ruby BRL_UCSC_downloader.rb -o hgdownload.cse.ucsc.edu -a mm9 -f xenoMrna.txt.gz -d /users/ybai/work/Project6/mRNA_EST/Other_mRNA/ -e ybai@ws59.hgsc.bcm.tmc.edu
ruby BRL_UCSC_downloader.rb -o hgdownload.cse.ucsc.edu -a mm9 -f chr*_intronEst.txt.gz -d /users/ybai/work/Project6/mRNA_EST/Spliced_EST/ -e ybai@ws59.hgsc.bcm.tmc.edu
ruby BRL_UCSC_downloader.rb -o hgdownload.cse.ucsc.edu -a mm9 -f miRNA.txt.gz -d /users/ybai/work/Mouse_mRNA/ -e ybai@ws59.hgsc.bcm.tmc.edu
ruby BRL_UCSC_downloader.rb -o hgdownload.cse.ucsc.edu -a mm7 -f miRNA.txt.gz -d /users/ybai/work/Mouse_mm7-mRNA/ -e ybai@ws59.hgsc.bcm.tmc.edu
ruby BRL_UCSC_downloader.rb -o hgdownload.cse.ucsc.edu -a mm6 -f miRNA.txt.gz -d /users/ybai/work/Mouse_mm6-mRNA/ -e ybai@ws59.hgsc.bcm.tmc.edu
ruby BRL_UCSC_downloader.rb -o hgdownload.cse.ucsc.edu -a mm5 -f miRNA.txt.gz -d /users/ybai/work/Mouse_mm5-mRNA/ -e ybai@ws59.hgsc.bcm.tmc.edu
ruby BRL_UCSC_downloader.rb -o hgdownload.cse.ucsc.edu -a mm9 -f affyGnf1m.txt.gz -d /users/ybai/work/Project6/Expression_Regulation/Affy_GNF1M/ -e ybai@ws59.hgsc.bcm.tmc.edu
ruby BRL_UCSC_downloader.rb -o hgdownload.cse.ucsc.edu -a mm9 -f affyMOE430.txt.gz -d /users/ybai/work/Project6/Expression_Regulation/Affy_MOE430/ -e ybai@ws59.hgsc.bcm.tmc.edu
ruby BRL_UCSC_downloader.rb -o hgdownload.cse.ucsc.edu -a mm9 -f affyU74.txt.gz -d /users/ybai/work/Project6/Expression_Regulation/Affy_U74/ -e ybai@ws59.hgsc.bcm.tmc.edu
ruby BRL_UCSC_downloader.rb -o hgdownload.cse.ucsc.edu -a mm9 -f gnfAtlas2.txt.gz -d /users/ybai/work/Project6/Expression_Regulation/GNF_Atlas2/ -e ybai@ws59.hgsc.bcm.tmc.edu
ruby BRL_UCSC_downloader.rb -o hgdownload.cse.ucsc.edu -a mm9 -f affyGnfU74A.txt.gz -d /users/ybai/work/Project6/Expression_Regulation/Affy_U74A/ -e ybai@ws59.hgsc.bcm.tmc.edu
ruby BRL_UCSC_downloader.rb -o hgdownload.cse.ucsc.edu -a mm9 -f affyGnfU74B.txt.gz -d /users/ybai/work/Project6/Expression_Regulation/Affy_U74B/ -e ybai@ws59.hgsc.bcm.tmc.edu
ruby BRL_UCSC_downloader.rb -o hgdownload.cse.ucsc.edu -a mm9 -f affyGnfU74C.txt.gz -d /users/ybai/work/Project6/Expression_Regulation/Affy_U74C/ -e ybai@ws59.hgsc.bcm.tmc.edu
ruby BRL_UCSC_downloader.rb -o hgdownload.cse.ucsc.edu -a mm8 -f jaxQTL*.gz -d /users/ybai/work/Mouse_Project3/MGI_QTL -e ybai@ws59.hgsc.bcm.tmc.edu
ruby BRL_UCSC_downloader.rb -o hgdownload.cse.ucsc.edu -a mm5 -f jaxQTL*.gz -d /users/ybai/work/Mouse_Project3/MGI_QTL_mm5 -e ybai@ws59.hgsc.bcm.tmc.edu
ruby BRL_UCSC_downloader.rb -o hgdownload.cse.ucsc.edu -a mm8 -f wssdCoverage.txt.gz -d /users/ybai/work/Mouse_Project3//WSSD_Coverage -e ybai@ws59.hgsc.bcm.tmc.edu
ruby BRL_UCSC_downloader.rb -o hgdownload.cse.ucsc.edu -a mm6 -f *_chainSelf*.txt.gz -d /users/ybai/work/Project5/Self_Chain -e ybai@ws59.hgsc.bcm.tmc.edu
ruby BRL_UCSC_downloader.rb -o hgdownload.cse.ucsc.edu -a mm8 -f rinnSex.txt.gz -d /users/ybai/work/Project6/Expression_Regulation/Rinn_Sex_Exp -e ybai@ws59.hgsc.bcm.tmc.edu
ruby BRL_UCSC_downloader.rb -o hgdownload.cse.ucsc.edu -a mm8 -f affyMoEx1Probe.txt.gz -d /users/ybai/work/Project6/Expression_Regulation/Affy_Exon -e ybai@ws59.hgsc.bcm.tmc.edu
ruby BRL_UCSC_downloader.rb -o hgdownload.cse.ucsc.edu -a mm7 -f picTarMiRNAChicken.txt.gz -d /users/ybai/work/Project6/Expression_Regulation/PicTar_miRNA -e ybai@ws59.hgsc.bcm.tmc.edu
ruby BRL_UCSC_downloader.rb -o hgdownload.cse.ucsc.edu -a mm7 -f picTarMiRNADog.txt.gz -d /users/ybai/work/Project6/Expression_Regulation/PicTar_miRNA -e ybai@ws59.hgsc.bcm.tmc.edu
ruby BRL_UCSC_downloader.rb -o hgdownload.cse.ucsc.edu -a mm8 -f cgapSage*.txt.gz -d /users/ybai/work/Project6/mRNA_EST/CGAP_SAGE -e ybai@ws59.hgsc.bcm.tmc.edu
ruby BRL_UCSC_downloader.rb -o hgdownload.cse.ucsc.edu -a mm7 -f rikenCageTc.txt.gz -d /users/ybai/work/Project6/mRNA_EST/CAGE_TC -e ybai@ws59.hgsc.bcm.tmc.edu
ruby BRL_UCSC_downloader.rb -o hgdownload.cse.ucsc.edu -a mm6 -f rikenCageTc.txt.gz -d /users/ybai/work/Project6/mRNA_EST/CAGE_TC -e ybai@ws59.hgsc.bcm.tmc.edu
ruby BRL_UCSC_downloader.rb -o hgdownload.cse.ucsc.edu -a mm5 -f rikenCageTc.txt.gz -d /users/ybai/work/Project6/mRNA_EST/CAGE_TC -e ybai@ws59.hgsc.bcm.tmc.edu
ruby BRL_UCSC_downloader.rb -o hgdownload.cse.ucsc.edu -a mm5 -f tigrGeneIndex.txt.gz -d /users/ybai/work/Project6/mRNA_EST/TIGR_Gene_Index -e ybai@ws59.hgsc.bcm.tmc.edu

"
end

class MyDownloader
  def initialize(inputsHash)
  end
  def download(inputsHash)
    hostFile = inputsHash['--hostFile'].strip
    assemblyName = inputsHash['--assemblyName'].strip
    fileName = inputsHash['--fileName'].strip
    dDirectoryOutput = inputsHash['--dDirectoryOutput'].strip  
    emailAddress = inputsHash['--emailAddress'].strip
    # start to connect to host  
    begin
      puts "Checking connections.."
      timeout(8000){
        ftp = Net::FTP.open(hostFile) do |ftp|
          ftp.passive = true
          puts "Checking user name and password..."
          begin
            ftp.login('anonymous', emailAddress)
          rescue Net::FTPError
            $stderr.puts "Could authentificate... Details: " + $!
            exit(FAILED)
          else
            puts "Authentification is ok..."
          end
          puts "Checking availbility of given assembly on host side...."
          # --------------------------------------------------------
          # If the assembly is available, start downloading; otherwise, output the message and no downlaoding happens... 
          #---------------------------------------------------------
          begin
            current_assembly = assemblyName
            ftp.chdir("goldenPath/#{current_assembly}/database")
            Dir.chdir("#{dDirectoryOutput}")
            puts "Starting downloading...."
            files = ftp.nlst(fileName) 
            files.each {|file| ftp.getbinaryfile(file, file)}
            puts "Downloading completes! Please check your directory for files, thank you!"
          rescue Net::FTPError => err
            $stderr.puts "No downloading occurrs.... Details: #{err.message}" 
            exit(FAILED)
          end
	end
      }
    rescue Timeout::Error
      $stderr.puts "Timeout while connecting to server.."
      exit(FAILED)
    end 
  end 
end

# ##############################################################################
# MAIN
# ##############################################################################
begin
  $stderr.puts "#{Time.now} BEGIN (Mem: #{BRL::Util::MemoryInfo.getMemUsageStr()})"
  optsHash = processArguments()
  downloader = MyDownloader.new(optsHash)
  downloader.download(optsHash)
  $stderr.puts "#{Time.now} DONE"
  exit(OK)
rescue => err
  $stderr.puts "Error occurs... Details: #{err.message}"
  $stderr.puts err.backtrace.join("\n")
  exit(FATAL)
end


