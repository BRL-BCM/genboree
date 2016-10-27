#!/usr/bin/env bash

#if [ $# != 1 ]
#then
#  echo "usage: `basename $0` <filename>"
#  exit 1
#fi

rm -f my.bed
rm -f lift_my.bed
rm -f lift_my.unMapped
rm -f out1.lff
rm -f out2.lff
export UCSC_CHAIN_DIR=/pearson/data/pengy/raw_data/public/UCSC_Genome_Browser/ucsc/hgdownload.cse.ucsc.edu/goldenPath
./main.pl --srcLff=src.lff --srcVer=mm9 --destVer=hg19 --lffType=lffType --lffSubtype=lffSubtype
unset UCSC_CHAIN_DIR
