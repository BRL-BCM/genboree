#!/bin/bash

baseDir=`pwd`


cd $baseDir
cd ampliconCompletion
for i in *.report; do result=`grep -v "^#" $i|wc -l`;name=`echo $i|sed -e 's/^[a-zA-Z]*_//' -e 's/.0-/-to-/' -e 's/.0_b.report//'`; printf "%s\t%s\n" $name $result; done >results.txt

cd $baseDir
cd geneCompletion
for i in *.report; do result=`grep -v "^#" $i|wc -l`;name=`echo $i|sed -e 's/^[a-zA-Z]*_//' -e 's/.0-/-to-/' -e 's/.0_b.report//'`; printf "%s\t%s\n" $name $result; done >results.txt

cd $baseDir
cd geneOneXCoverage
for i in *.report; do result=`grep -v "^#" $i|wc -l`;name=`echo $i|sed -e 's/^[a-zA-Z]*_//' -e 's/.0-/-to-/' -e 's/.0_b.report//'`; printf "%s\t%s\n" $name $result; done >results.txt

cd $baseDir
cd geneTwoXCoverage
for i in *.report; do result=`grep -v "^#" $i|wc -l`;name=`echo $i|sed -e 's/^[a-zA-Z]*_//' -e 's/.0-/-to-/' -e 's/.0_b.report//'`; printf "%s\t%s\n" $name $result; done >results.txt

cd $baseDir
cd sampleCompletion
for i in *.report; do result=`grep -v "^#" $i|wc -l`;name=`echo $i|sed -e 's/^[a-zA-Z]*_//' -e 's/.0-/-to-/' -e 's/.0_b.report//'`; printf "%s\t%s\n" $name $result; done >results.txt
