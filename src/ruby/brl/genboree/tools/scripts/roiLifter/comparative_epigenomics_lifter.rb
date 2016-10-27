#!/usr/bin/env ruby

# Load libraries
require 'brl/util/scriptDriver'

module Script
  # Driver Class, must inherit from Script::ScriptDriver
  class DriveROILifter < Script::ScriptDriver
    # ------------------------------------------------------------------
    # Sub-class interface - must provide & implement these things from ScriptDriver
    # ------------------------------------------------------------------
    VERSION = "0.1"                                            # INTERFACE: provide version string

    USAGE_INFO = "
    USAGE:
      comparative_epigenomics_lifter.rb --srcLff={lffPath} --srcVer={ucscGenomeVer} --destVer={ucscGenomeVer} --lffType={outputLffType} --lffSubtype={outputLffSubtype} [--minRatio={minSrcVsDestRatio}] [--multiple]

    AUTHOR: Peng Yu, Sameer Paithankar, Andrew R Jackson

    DESCRIPTION: This wrapper is intended to used for running the ROI-Lifter tool via the Genboree Workbench

    ARGUMENTS:
      -j  --inputFile                     => input file in json format\n#{RunScript.HELP_AND_VERSION_USAGE}
    "

    ARGS_ARRAY = [
      [ '--srcLff', '-i', GetoptLong::REQUIRED_ARGUMENT ],
      [ '--srcVer', '-s', GetoptLong::REQUIRED_ARGUMENT ],
      [ '--destVer', '-d', GetoptLong::REQUIRED_ARGUMENT ],
      [ '--lffType', '-t', GetoptLong::REQUIRED_ARGUMENT ],
      [ '--lffSubtype', '-b', GetoptLong::REQUIRED_ARGUMENT ],
      [ '--minRatio', '-r', GetoptLong::REQUIRED_ARGUMENT ],
      [ '--multiple', '-m', GetoptLong::NO_ARGUMENT ]
    ]
    # ------------------------------------------------------------------

    attr_accessor :srcLff, :srcVer, :destVer, :lffType, :lffSubtype, :minMatch, :multiple

    # ABSTRACT INTERFACE METHOD: run()
    # - To be implemented by sub-classes
    # - No-arg method that causes driver to run application. MUST
    #   return a numerical exitCode suitable for calling exit() on.
    #   Thus 0 means success.
    def run()
      if(extractArgs())
        

      else # problem with command-line arg values provided
        @exitCode = EXIT_ARGS_ISSUE
      end
      return @exitCode
    end

    # Extract to convenient instance variables and do some validation at same time
    def extractArgs()
      retVal = false
      @srcLff = @optsHash['--srcLff']
      if(@srcLff and File.exist?(@srcLff))
        @srcVer = @optsHash['--srcVer'].strip
        @destVer = @optsHash['--destVer'].strip
        if(@srcVer.downcase != @destVer.downcase)
          @lffType = @optsHash['--lffType'].strip
          @lffSubtype = @optsHash['--lffSubType'].strip
          @trackName = "#{@lffType.strip}:#{@lffSubType.strip}"
          if(!@trackName.index(":"))
            $stderr.puts "\nWARNING: the track name #{@trackName} will be longer than the recommended 19 characters." unless(@trackName.size <= 19)
            @minRatio = ((@optsHash['--minRatio'] and !@optsHash['--minRatio'].empty?) ? @optsHash['--minRatio'].to_f : 0.95)
            if(@minRatio >= 0.0 and @minRatio < 1.0)
              @multiple = @optsHash['--minRatio'] ? true : false
              retVal = true # all ok
            else
              $stderr.puts "\nERROR: the minRatio argument is not a positive number between 0.0 and 1.0"
            end
          else
            $stderr.puts "\nERROR: the lffType and/or lffSubtype arguments have ':' in them, which is a delimiter and thus not allowed."
          end
        else
          $stderr.puts "\nERROR: the source and destination genome versions appear to be the same."
        end
      else
        $stderr.puts "\nERROR: The input LFF file doesn't seem to indicate a valid file."
      end
      return retVal
    end
  end # class DriveROILifter
end # module Script

########################################################################
# MAIN
########################################################################
Script::main(Script::DriveROILifter)


open SRC_LFF, $srcLff or die "ERROR: can't open $srcLff for reading." ;
open BED_FILE, '>my.bed' or die "ERROR: can't open temp bed file for writing." ;

while(<SRC_LFF>) {
  chomp;
  my @array=split /\t/;

  my $class=$array[0];
  my $name=$array[1];
  my $type=$array[2];
  my $subtype=$array[3];
  my $entry_point=$array[4];
  my $start=$array[5];
  my $stop=$array[6];
  my $strand=$array[7];
  my $phase=$array[8];
  my $score=$array[9];
  my $qStart=$array[10];
  my $qStop=$array[11];
  my $attribute_commments=$array[12];

#  my @attribute_commments=split /\s*;\s*/, $attribute_commments;
#  my @match_attribute=grep /conservedRegionID=\d+$/, @attribute_commments;
#  $match_attribute[0] =~ /conservedRegionID=(\d+)$/;
#  my $conservedRegionID=$1;

  my $bed_chrom=$entry_point;
  my $bed_chromStart=$start;
  my $bed_chromEnd=$stop;
#  my $bed_name=$conservedRegionID;
  my $bed_name=$.;
  my $bed_score=1000;
  my $bed_strand=$strand;

  print BED_FILE join("\t", $bed_chrom, $bed_chromStart, $bed_chromEnd, $bed_name, $bed_score, $bed_strand), "\n";
}

close BED_FILE;
close SRC_LFF;

use Env qw(UCSC_CHAIN_DIR);
#my $chain="/pearson/data/pengy/raw_data/public/UCSC_Genome_Browser/ucsc/hgdownload.cse.ucsc.edu/goldenPath/$srcVer/vs$destVer/$srcVer.$destVer.all.chain.gz";
my $chain="$UCSC_CHAIN_DIR/$srcVer/vs" . ucfirst($destVer) . "/$srcVer.$destVer.all.chain.gz";
my $multipleArg = (($multiple eq "1") ? " -multiple " : "") ;
my $cmd = "liftOver -minMatch=$minMatch $multipleArg my.bed $chain lift_my.bed lift_my.unMapped" ;
`$cmd` ;
my $cmdExitCode = $? ;
my $cmdExitStatus = ($? >>8) ;
($cmdExitCode == 0) or die "ERROR: the liftOver command seems to have failed with exit status $cmdExitStatus. Command was:\n    $cmd\n\n" ;

open OUT1_LFF, '>out1.lff' or die "ERROR: can't open lff file for $srcVer regions." ;
open OUT2_LFF, '>out2.lff' or die "ERROR: can't open lff file for $destVer regions." ;
open SRC_LFF, $srcLff or die "ERROR: can't open $srcLff for reading." ;

open LIFT_BED_FILE, 'lift_my.bed';

while(<LIFT_BED_FILE>) {
  chomp;
  my ($bed_chrom, $bed_chromStart, $bed_chromEnd, $bed_name, $bed_score, $bed_strand)=split /\t/;

  while(my $line=<SRC_LFF>) {
    chomp;
    my @array=split /\t/, $line;

    my $class=$array[0];
    my $name=$array[1];
    my $type=$array[2];
    my $subtype=$array[3];
    my $entry_point=$array[4];
    my $start=$array[5];
    my $stop=$array[6];
    my $strand=$array[7];
    my $phase=$array[8];
    my $score=$array[9];
    my $qStart=$array[10];
    my $qStop=$array[11];
    my $attribute_commments="$array[12]; conservedRegionID=$bed_name;";

    #print "$attribute_commments\n";

#    my @attribute_commments=split /\s*;\s*/, $attribute_commments;
#    my @match_attribute=grep /conservedRegionID=\d+$/, @attribute_commments;
#    $match_attribute[0] =~ /conservedRegionID=(\d+)$/;
#    my $conservedRegionID=$1;

#    if($conservedRegionID eq $bed_name) {
    if($. eq $bed_name) {
      print OUT1_LFF join("\t", $class, $name, $lffType, $lffSubtype, $entry_point, $start, $stop, $strand, $phase, $score, $qStart, $qStop, $attribute_commments), "\n";
      print OUT2_LFF join("\t", $class, $name, $lffType, $lffSubtype, $bed_chrom, $bed_chromStart, $bed_chromEnd, $bed_strand, $phase, $score, $qStart, $qStop, $attribute_commments), "\n";
      last;
    } else {
      next;
    }
  }
}

exit(0) ;
