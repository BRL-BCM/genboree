#!/bin/bash

####### Programs
VALIDATOR="/usr/local/brl/local/apache/ruby/brl/fileFormats/tcgaParsers/validators.rb"
LFFGENERATOR="/usr/local/brl/local/apache/ruby/brl/fileFormats/tcgaParsers/lffGenerator.rb"
MAPPING="/usr/local/brl/local/apache/ruby/brl/fileFormats/tcgaParsers/mappingFilesGenerator.rb"
SAMPLESTATS="/usr/local/brl/local/apache/ruby/brl/fileFormats/tcgaParsers/sampleStats.rb"
MODIFYLFFS="/usr/local/brl/local/apache/ruby/brl/fileFormats/tcgaParsers/modifyLffs.rb"
GAPGENERATOR="/usr/local/brl/local/apache/ruby/brl/fileFormats/tcgaParsers/gapFileGenerator.rb"
SUMMARYGENERATOR="/usr/local/brl/local/apache/ruby/brl/fileFormats/tcgaParsers/summaryGenerator.rb"


############ Missing Files
missingAmpliconToLoci="missingA2Loci.missing"
missingAmpliconToRois="missingA2Roi.missing"
missingRoiToLoci="missingR2Loci.missing"

############ Duplicated Files
duplicatedRoiToLoci="dupR2Loci.duplicated"
duplicatedAmpliconToRois="dupA2Roi.duplicated"
duplicatedAmpliconToLoci="dupA2Loci.duplicated"

####### Mapping Files
ampliconToRoi="ampliconToRoi.map"
roiToLoci="roiToLoci.map"
ampliconToLociFileName="ampliconToLoci.map"
roiToCoverage="roiToCoverage.map"
ampliconToTotal="ampliconCompletion.summary"
sampleToTotal="sampleCompletion.summary"
geneSummaryFile="geneCoverage.summary"
geneCompletionFile="geneCompletion.summary"
########## Big table file
sampleAmpliconTableFile="sampleAmpliconTable.table"

######## Lff Files
ampliconLffFileName="amplicons.lff"
primerLffFileName="primers.lff"
roiLffFileName="roi.lff"
roiSequencingLffFileName="roiSequencing.lff"
gapFileName="gaps.lff"
tempFile="temp.lff"
ampliconSequencingFileName="Amplicon_Sequencing_File.txt.gz"
ampliconSeqLffFileName="ampliconSeq.lff"


 
if [ $# -lt 7 ]
then
  echo "usage: $0 AMPLICON_FILE ROI_FILE SAMPLE_FILE SAMPLESEQUENCING_FILE ROISEQUENCING_FILE LOCI_FILE INSTITUTION"
  exit
fi

baseDir=`pwd`


########### list of genes
listOfGenesFileName="listOfGenes.txt"
################ INPUT Files from Centers
ampliconFile=$1
roiFile=$2
sampleFile=$3
sampleSequencing=$4
roiSequence=$5
lociFile=$6
institution=$7

############### Variables
CLASSNAME=$institution"-Report-Data"
TYPE=$institution
ampliconSubtype="amplicon"
primerSubtype="primer"
roiSubtype="roi"
attributeName="perc1xCoverage"
gapCutOff="0.001"
gapSubtype="gaps"
fileCompletionPrefix="geneCompletion"
fileCompletionSubFix="report"
columnCompletionNumber="4"
numberOfColumnsCompletion="5"
fileOneXCoveragePrefix="geneOneXCoverage"
fileTwoXCoveragePrefix="geneTwoXCoverage"
fileCoverageSubFix="report"
columnOneXCoverageNumber="3"
columnTwoXCoverageNumber="4"
numberOfColumnsCoverage="5"
sampleCompletionPrefix="sampleCompletion"
sampleCompletionSubFix="report"
columnSampleCompletionNumber="3"
numberOfColumnsSampleCompletion="4"
sampleAmpliconCompletionPrefix="ampliconCompletion"
sampleAmpliconCompletionSubFix="report"
columnSampleAmpliconCompletionNumber="3"
numberOfColumnsSampleAmpliconCompletion="4"



localDate=`date +'%Y-%m-%d @ %H:%M:%S (%s)'`
echo "RUNNING LFF Modifiers  -- "$localDate
echo $MODIFYLFFS --tabDelimitedFileName $roiToLoci --lffFileName $roiLffFileName --outPutFileName $tempFile
echo mv $tempFile $roiLffFileName
echo $MODIFYLFFS --tabDelimitedFileName $roiToCoverage --lffFileName $roiLffFileName --outPutFileName $tempFile
echo mv $tempFile $roiLffFileName
echo $MODIFYLFFS --tabDelimitedFileName $ampliconToRoi --lffFileName $ampliconLffFileName --outPutFileName $tempFile
echo mv $tempFile $ampliconLffFileName
echo $MODIFYLFFS --tabDelimitedFileName $ampliconToLociFileName --lffFileName $ampliconLffFileName --outPutFileName $tempFile
echo mv $tempFile $ampliconLffFileName
echo $MODIFYLFFS --tabDelimitedFileName $ampliconToTotal --lffFileName $ampliconLffFileName --outPutFileName $tempFile
echo mv $tempFile $ampliconLffFileName
echo "RUNNING GAPS Generator  ---- "
echo $GAPGENERATOR --roiLffFileName $roiLffFileName --gapLffFile $gapFileName --attributeName $attributeName --attributeThreshold $gapCutOff --subtype $gapSubtype
localDate=`date +'%Y-%m-%d @ %H:%M:%S (%s)'`

