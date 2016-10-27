#! /bin/sh

tab=$'\t';
fileName=$1 ;
location=$2 ;
suffix=$3 
chrom=`cat $fileName |cut -d$'\t' -f5|sort -d|uniq`; 
types=`cat $location"tracks.txt"`; 
tName=`cat $fileName |cut -d$'\t' -f3,4|sort -d|uniq|sed -e "s/$tab/:/"`; 
tName=`echo $tName|sed -e "s/ //"`;
for i in $types ; 
do for yy in $chrom; 
do ww=`echo $yy`;
lffIntersect.rb -f $i -s $tName -l ./$fileName,$location$ww.$suffix -o $i.$yy".nearMyGenes" -n $i -V; done; done
