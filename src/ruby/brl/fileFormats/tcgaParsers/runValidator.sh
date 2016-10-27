#!/bin/bash

####### Programs
VALIDATOR="/usr/local/brl/local/apache/ruby/brl/fileFormats/tcgaParsers/validators.rb"


if [ $# -lt  5 ]
then
  echo "usage: $0 AMPLICON_FILE ROI_FILE SAMPLE_FILE SAMPLESEQUENCING_FILE ROISEQUENCING_FILE"
  exit
fi


################ INPUT Files from Centers
ampliconFile=$1
roiFile=$2
sampleFile=$3
sampleSequencing=$4
roiSequence=$5
#ampliconSequence=$6



$VALIDATOR --roiFileName $roiFile --sampleFileName $sampleFile --ampliconFileName $ampliconFile  --sampleSequencingFileName $sampleSequencing --roiSequencingFileName $roiSequence
##--ampliconSequencingFile  $ampliconSequence