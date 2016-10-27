#!/usr/bin/env perl

use strict;
use warnings;

use strict;
use warnings;
use Getopt::Long;


#my $srcLff='src.lff';
#my $srcVer='mm9';
#my $destVer='hg19';
#my $lffType='lffType';
#my $lffSubtype='lffSubtype';

my $srcLff;
my $srcVer;
my $destVer;
my $lffType;
my $lffSubtype;
my $minMatch ;
my $multiple ;

GetOptions(
  "srcLff=s" => \$srcLff,
  "srcVer=s" => \$srcVer,
  "destVer=s" => \$destVer,
  "lffType=s" => \$lffType,
  "lffSubtype=s" => \$lffSubtype,
  "minRatio=s" => \$minMatch,
  "multiple=s" => \$multiple
);

# USAGE:
if(!($srcLff and $srcVer and $destVer and $lffType and $lffSubtype))
{
  print "\nUSAGE: ./comparative_epigenomics_lifter.pl --srcLff={lffPath} --srcVer={ucscGenomeVer} --destVer={ucscGenomeVer} --lffType={outputLffType} --lffSubtype={outputLffSubtype} [--minRatio={minSrcVsDestRatio}]\n\n" ;
  exit(2) ;
}

# --minRatio is optional:
if(!$minMatch)
{
  $minMatch = 0.95 ;
}

print "DEBUG: minMatch = $minMatch\nargv: $ARGV" ;

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
