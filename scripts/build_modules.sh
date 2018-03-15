#!/bin/bash

set -e  # stop on first error
set -u  # stop when tries to use uninitialized variable

DIR_SCRIPTS="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"   # directory with scripts
source ${DIR_SCRIPTS}/conf_build.sh

set -v  # print commands


# java 1.6 (jre)
func_module 'jdk' '1.6'
func_module_add 'module unload jdk/1.5'
func_module_add "prepend-path PATH ${MOD_DIR}/bin"
func_module_add "prepend-path LD_LIBRARY_PATH ${MOD_DIR}/lib"
func_module_add "prepend-path MANPATH ${MOD_DIR}/man"
func_module_add "setenv JAVA_HOME ${MOD_DIR}"
func_module_add "setenv SITE_JARS ${DIR_TARGET}/lib/java/site_java/${MOD_VERSION}/jars"
func_get_package "jre-1.6.0_45"
mkdir -p ${DIR_TARGET}/lib/java/site_java/${MOD_VERSION}/jars
mv ./jre1.6.0_45/* ${MOD_DIR}/
rm -rf  jre1.6.0_45  jre-1.6.0_45*


# bowtie1
func_module_bin 'bowtie' '1.0'
func_get_package "bowtie-1.0.1"
cd bowtie-1.0.1
make -j ${CORES_NUMBER} BITS=64
mv bowtie         ${MOD_DIR}/bin/
mv bowtie-build   ${MOD_DIR}/bin/
mv bowtie-inspect ${MOD_DIR}/bin/
cd ..
rm -rf bowtie-1.0.1*


# bowtie2
func_module_bin 'bowtie2' '2.2'
func_module_add "prepend-path PATH ${MOD_DIR}/scripts"
func_get_package "bowtie2-2.2.1"
cd bowtie2-2.2.1
make -j ${CORES_NUMBER}
mv bowtie2*  ${MOD_DIR}/bin/
mv scripts   ${MOD_DIR}/
cd ..
rm -rf bowtie2-2.2.1*


# bwa
func_module_bin 'bwa' '0.7'
func_get_package "bwa-0.7.9a"
cd bwa-0.7.9a
func_run "make all CFLAGS='-Wall -Wno-unused-function -O3' -j ${CORES_NUMBER}"
mv bwa  ${MOD_DIR}/bin/
cd ..
rm -rf bwa-0.7.9a*


# ChromHMM
func_module_bin 'ChromHMM' '1.1'
func_module_add 'module load jdk/1.6'
func_get_package "ChromHMM-1.10"
cd ChromHMM
cp ChromHMM.jar   ${MOD_DIR}/bin/
cp -R COORDS      ${MOD_DIR}/bin/
cp -R ANCHORFILES ${MOD_DIR}/bin/
echo $'#!/bin/bash\n\njava -Xmx8000M -jar -Djava.awt.headless=true '${MOD_DIR}$'/bin/ChromHMM.jar "$@"\n' > ${MOD_DIR}/bin/ChromHMM 
chmod 775 ${MOD_DIR}/bin/ChromHMM
cd ..
rm -rf ChromHMM*


# Kevin's wgsMicrobiomePipeline
#func_module_bin 'wgsMicrobiomePipeline' '0.1'
#func_module_add 'prepend-path RUBYLIB    ${INSTALL_DIR}/lib/ruby'
#func_module_add 'prepend-path PYTHONPATH ${INSTALL_DIR}/lib/python'
#func_module_add 'module load sra-toolkit'
#func_module_add 'module load popoolation'
#func_module_add 'module load graphlan'
#func_module_add 'module load metaphlan'
#func_module_add 'module load lefse'
#func_module_add 'module load velvet'
#func_module_add 'module load hmmer'
#func_module_add 'module load graphviz'
#func_module_add 'module load humann'
#func_module_add 'module load usearch'
#func_module_add 'module load amos'
#func_module_add 'module load wgs-assembler'
#func_module_add 'module load metAMOS'
#func_get_package "wgsMicrobiomePipeline-0.1"
#cd wgsMicrobiomePipeline-0.1
#patch -p1 < ../wgsMicrobiomePipeline-0.1_WGS_construct_cmds.patch              # fix bug: hardcoded path /scratch
#patch -p1 < ../wgsMicrobiomePipeline-0.1_cluster_conditional_job_wrapper.patch # my changes
#cd ..
#mv wgsMicrobiomePipeline-0.1/lib ${MOD_DIR}/
#cd ${MOD_DIR}/bin
#find ../lib -type f -exec ln -s {} \;
#cd -
#rm -rf wgsMicrobiomePipeline-0.1*


# sratoolkit (needed by wgsMicrobiomePipeline)
func_module 'sra-toolkit' '2.3'
func_module_add "prepend-path PATH  ${MOD_DIR}/bin64"
func_module_add "prepend-path LD_LIBRARY_PATH ${MOD_DIR}/lib64"
func_get_package 'sratoolkit-2.3.5-2'
cd sratoolkit-2.3.5-2
# this Makefile downloads and compiles libz and libbz2 by default (!!!)
# we want to skip this and provide our own libz and libbz2 version
rm -rf ./libs/ext/*
echo "all:" > ./libs/ext/Makefile  # fake makefile
mkdir -p ${MOD_DIR}/linux/gcc/dyn/x86_64/rel/ilib/
ln -s  ${DIR_TARGET}/lib/libbz2.a  ${MOD_DIR}/linux/gcc/dyn/x86_64/rel/ilib/libbz2.a
ln -s  ${DIR_TARGET}/lib/libz.a    ${MOD_DIR}/linux/gcc/dyn/x86_64/rel/ilib/libz.a
# end of workaround
func_run "make OUTDIR=${MOD_DIR} out"
func_run "make GCC dynamic release"
func_run "make"
cd ..
rm -rf sratoolkit-2.3.5-2*


# popoolation (needed by wgsMicrobiomePipeline)
func_module_bin 'popoolation' '1.2'
func_module_add 'prepend-path PERLLIB  ${INSTALL_DIR}/Modules'
func_module_add 'prepend-path PERL5LIB ${INSTALL_DIR}/Modules'
func_get_package 'popoolation_1.2.2'
mv popoolation_1.2.2/* ${MOD_DIR}/
cd ${MOD_DIR}/bin
find .. -type f -name "*.pl" -exec ln -s {} \;
find .. -type f -name "*.pl" -exec chmod +x {} \;
cd -
rm -rf popoolation_1.2.2*


#python) graphlan
func_module_bin 'graphlan' '0.9'
func_module_add 'prepend-path PYTHONPATH ${INSTALL_DIR}'
func_get_package "graphlan-0.9.6"
cd graphlan-0.9.6
mv  ./graphlan_annotate.py  ./graphlan.py  ${MOD_DIR}/bin/
mv  ./*  ${MOD_DIR}/
cd ..
rm -rf graphlan-0.9.6*


# nsegata-metaphlan (needed by wgsMicrobiomePipeline)
#func_module_bin 'metaphlan' '1.7'
#func_module_add 'module load bowtie2'
#func_get_package "nsegata-metaphlan-1.7.8"
#mv nsegata-metaphlan-1.7.8/* ${MOD_DIR}/
#cd ${MOD_DIR}/bin
#find .. -type f -name "*.py" -exec ln -s {} \;
#cd -
#rm -rf nsegata-metaphlan-1.7.8*


# nsegata-lefse (needed by wgsMicrobiomePipeline)
func_module_bin 'lefse' '1.0'
func_get_package 'nsegata-lefse-1.0.7'
rm nsegata-lefse-1.0.7/__init__.py
mv nsegata-lefse-1.0.7/* ${MOD_DIR}/
cd ${MOD_DIR}/bin
find .. -maxdepth 1 -type f -name "*.py" -exec ln -s {} \;
cd -
rm -rf nsegata-lefse-1.0.7*


# hmmer (needed by wgsMicrobiomePipeline)
#func_module_binlib 'hmmer' '3.1'
#func_module_add 'prepend-path INCLUDE ${INSTALL_DIR}/include'
#func_module_add 'prepend-path MANPATH ${INSTALL_DIR}/share/man'
#func_get_package "hmmer-3.1b1"
#cd hmmer-3.1b1
#func_run "./configure --prefix=${MOD_DIR} --enable-sse --enable-threads"
#func_run "make -j ${CORES_NUMBER}"
#func_run "make install"
#func_run_test "make check"
#cd ..
#rm -rf hmmer-3.1b1*


# graphviz (needed by wgsMicrobiomePipeline)
func_module_binlib 'graphviz' '2.38'
func_module_add 'prepend-path INCLUDE ${INSTALL_DIR}/include'
func_module_add 'prepend-path MANPATH ${INSTALL_DIR}/share/man'
func_get_package "graphviz-2.38.0"
cd graphviz-2.38.0
func_run "./configure --prefix=${MOD_DIR} --enable-python27=yes --enable-perl=no --without-x --without-gtk"
func_run "make -j ${CORES_NUMBER}"
func_run "make install"
func_run_test 'make installcheck'
cd ..
rm -rf graphviz-2.38.0*


# humann (needed by wgsMicrobiomePipeline)
#func_module_bin 'humann' '0.98'
#func_get_package 'humann-0.98'
#mv humann-0.98/* ${MOD_DIR}/
#cd ${MOD_DIR}/bin
#find ../src -type f -name "*.py" -exec ln -s {} \;
#cd -
#rm -rf humann-0.98*


# usearch 5.2 32-bit (needed by wgsMicrobiomePipeline)
#func_module_bin 'usearch' '5.2-32bit'
#func_get_package 'usearch5.2.32_i86linux32'
#mv usearch5.2.32_i86linux32 ${MOD_DIR}/bin/
#chmod +x ${MOD_DIR}/bin/usearch5.2.32_i86linux32
#ln -s usearch5.2.32_i86linux32 ${MOD_DIR}/bin/usearch
#rm -rf usearch5.2.32_i86linux32*


# MUMmer (needed by amos)
#func_module 'MUMmer' '3.23'
#func_module_add 'prepend-path PATH ${INSTALL_DIR}'
#func_get_package 'MUMmer3.23'
#mv MUMmer3.23/* ${MOD_DIR}/
#cd ${MOD_DIR}
#func_run "make install"   # this must be run in TARGET directory (paths are hardcoded!)
#cd -
#rm -rf MUMmer3.23*


# blat (needed by amos)
func_module_bin 'blat' '35'
func_get_package 'blatSrc35'
cd blatSrc
mkdir -p lib/x86_64
func_run "MACHTYPE=x86_64 make BINDIR=${MOD_DIR}/bin"
cd ..
rm -rf blatSrc*


# amos (needed by wgsMicrobiomePipeline)
#func_module_binlib 'amos' '3.1'
#func_module_add 'module load MUMmer'
#func_module_add 'module load blat'
#func_module_add 'prepend-path INCLUDE ${INSTALL_DIR}/include'
#func_module_add 'prepend-path MANPATH ${INSTALL_DIR}/share/man'
#func_get_package 'amos-3.1.0'
#cd amos-3.1.0
#patch -p1 < ../amos-3.1.0_find-tandem.patch  # my patch 
#func_run "module load MUMmer; module load blat; ./configure --prefix=${MOD_DIR} --without-x"
#func_run "module load MUMmer; module load blat; make"
#func_run "module load MUMmer; module load blat; make install"
#func_run_test "module load MUMmer; module load blat; make check"
#cd ..
#rm -rf amos-3.1.0*


# wgs-assembler 6.1 (needed by wgsMicrobiomePipeline)
#func_module 'wgs-assembler' '6.1'
#func_module_add 'prepend-path PATH            ${INSTALL_DIR}/Linux-amd64/bin'
#func_module_add 'prepend-path LD_LIBRARY_PATH ${INSTALL_DIR}/Linux-amd64/lib'
#func_module_add 'prepend-path PYTHONPATH      ${INSTALL_DIR}/Linux-amd64/bin/TIGR'
#func_get_package 'wgs-6.1'
#cd wgs-6.1
#patch -p1 < ../wgs-6.1_configure.patch    # my patch 
#patch -p1 < ../wgs-6.1_getAssembly.patch  # my patch 
#cd kmer
#func_run "PYTHONHOME=${DIR_TARGET} sh configure.sh"
#func_run "make install"
#cd ../src
#func_run "make"
#cd ..


# velvet (needed by wgsMicrobiomePipeline)
func_module_bin 'velvet' '1.2-maxkmer_51'
func_get_package 'velvet_1.2.10'
cd velvet_1.2.10
func_run "make -j ${CORES_NUMBER} MAXKMERLENGTH=51"
rm -rf ./data ./debian ./obj ./src ./third-party
mv ./* ${MOD_DIR}/
cd ..
cd ${MOD_DIR}/bin
ln -s ../velvetg
ln -s ../velveth
find ../contrib -type f -name "*.pl" -exec ln -s {} \;
find ../contrib -type f -name "*.py" -exec ln -s {} \;
find ../contrib -type f -name "*.sh" -exec ln -s {} \;
cd -
rm -rf velvet_1.2.10*


# rdp-classifier
func_module 'rdp-classifier' '2.2'
func_module_add 'prepend-path CLASSPATH ${INSTALL_DIR}/rdp_classifier-2.2.jar' 
# Main-Class: edu.msu.cme.rdp.classifier.rrnaclassifier.ClassifierCmd
func_get_package 'rdp_classifier_2.2'
mv rdp_classifier_2.2/lib                    ${MOD_DIR}/
mv rdp_classifier_2.2/rdp_classifier-2.2.jar ${MOD_DIR}/
rm -rf rdp_classifier_2.2*


# qiime
func_module_bin 'qiime' '1.2.0'
func_module_add 'prepend-path PYTHONPATH ${INSTALL_DIR}/lib/python2.7/site-packages/'
mkdir ${MOD_DIR}/lib
func_get_package 'qiime-1.2.0'
cd qiime-1.2.0
func_run "python setup.py install --prefix=${MOD_DIR}"
cd ..
rm -rf qiime-1.2.0*


# Denoiser  (http://www.microbio.me/denoiser/)
# it is part of qiime from version 1.3
func_module_bin 'mbwDeps' 'v1'     # name compatible with our cluster
func_get_package 'Denoiser_0.851'
cd Denoiser_0.851/FlowgramAlignment
func_run 'make all'
func_run 'make install'
cd ..
mv ./bin/* ${MOD_DIR}/bin/
cd ..
rm -rf Denoiser_0.851*


# FastQC  (http://www.bioinformatics.babraham.ac.uk/projects/fastqc/)
func_module_bin 'FastQC' '0.11'
func_module_add 'module load jdk/1.6'
func_get_package 'fastqc_v0.11.2'
mv ./FastQC/* ${MOD_DIR}/
chmod +x ${MOD_DIR}/fastqc
ln -s  ../fastqc  ${MOD_DIR}/bin/fastqc
rm -rf  fastqc_v0.11.2*  FastQC


# MetaGeneMark  (http://exon.gatech.edu/GeneMark/license_download.cgi)
func_module_bin 'MetaGeneMark' '64bit'
func_module_add 'setenv GENEMARK_LIC_FILE ${INSTALL_DIR}/lic/.gm_key'
func_get_package 'MetaGeneMark_linux_64'
mv MetaGeneMark_linux_64/MetaGeneMark/* ${MOD_DIR}/
ln -s  ../aa_from_gff.pl  ${MOD_DIR}/bin/aa_from_gff.pl
ln -s  ../gmhmmp          ${MOD_DIR}/bin/gmhmmp
ln -s  ../nt_from_gff.pl  ${MOD_DIR}/bin/nt_from_gff.pl
mkdir  ${MOD_DIR}/lic
mv  MetaGeneMark_linux_64_gm_key  ${MOD_DIR}/lic/.gm_key
rm -rf MetaGeneMark_linux_64*


# metAMOS  (grabbed from our cluster)
#func_module_bin 'metAMOS' '2011'
#func_module_add 'module load MetaGeneMark'
#func_module_add 'prepend-path PERL5LIB   ${INSTALL_DIR}/AMOS'
#func_module_add 'prepend-path PERLLIB    ${INSTALL_DIR}/AMOS'
#func_module_add 'prepend-path PYTHONPATH ${INSTALL_DIR}/Utilities'
#func_module_add 'setenv METAMOS_ROOT_DIR ${INSTALL_DIR}'
#func_get_package 'metAMOS_2011_from_cluster'
#mv metAMOS_2011_from_cluster/* ${MOD_DIR}/
#ln -s  ../../../../additional/metAMOS_Utilities/DB     ${MOD_DIR}/Utilities/DB
#ln -s  ../../../../additional/metAMOS_Utilities/krona  ${MOD_DIR}/Utilities/krona
#rm -rf metAMOS_2011_from_cluster*


# RSeqTools (http://homes.gersteinlab.org/people/as2665/)
func_module_bin 'RSeqTools' '0.7'
func_get_package 'rseqtools-0.7.0'
cd rseqtools-0.7.0
func_run "./configure --prefix=${MOD_DIR}"
func_run "make all -j ${CORES_NUMBER}"
func_run "make install"
cd ..
# a replacement/fix sent by Gerstein lab at Yale for the sam2mrf.py conversion utility module
chmod a+x rseqtools-0.7.0_sam2mrf/*
mv rseqtools-0.7.0_sam2mrf/* ${MOD_DIR}/bin/ 
rm -rf rseqtools-0.7.0*


# ViennaRNA (http://www.tbi.univie.ac.at/RNA/index.html#download)
func_module_bin 'ViennaRNA' '2.1'
func_get_package 'ViennaRNA-2.1.8'
cd ViennaRNA-2.1.8
func_run "./configure --prefix=${MOD_DIR} --without-doc-pdf --without-doc-html --without-doc"
func_run "make all -j ${CORES_NUMBER}"
func_run "make install"
cd ..
rm -rf cd ViennaRNA-2.1.8*


# phymmbl (http://www.cbcb.umd.edu/software/phymm/) - not needed by now
#func_module 'phymmbl' '4.0'
#func_module_add 'prepend-path PATH ${INSTALL_DIR}'
#func_get_package 'phymmbl-4.0'
#mv phymmbl-4.0/*        ${MOD_DIR}/
#mv phymmbl-4.0/.logs    ${MOD_DIR}/
#mv phymmbl-4.0/.scripts ${MOD_DIR}/
#rm -rf phymmbl-4.0*
# links to pre-build databases (must be installed as additional data)
#ln -s ${DIR_ADD}/phymmbl/blastData     ${MOD_DIR}/.blastData
#ln -s ${DIR_ADD}/phymmbl/genomeData    ${MOD_DIR}/.genomeData
#ln -s ${DIR_ADD}/phymmbl/taxonomyData  ${MOD_DIR}/.taxonomyData


# samtools
func_module_binlib 'samtools' '1.0'
func_module_add 'prepend-path INCLUDE ${INSTALL_DIR}/include'
func_module_add 'prepend-path MANPATH ${INSTALL_DIR}/shared/man'
func_get_package 'samtools-1.0'
cd samtools-1.0
func_run "make all -j ${CORES_NUMBER} DFLAGS='-D_FILE_OFFSET_BITS=64 -D_LARGEFILE64_SOURCE -D_CURSES_LIB=0'  LIBCURSES=''"
func_run "make install prefix=${MOD_DIR}"
cd ..
rm -rf samtools-1.0*


# sRNAbench 2.0 (grabbed from our cluster)
func_module 'sRNAbench' '2.0'
func_module_add 'module load jdk/1.6'
func_module_add 'module load ViennaRNA'
func_module_add 'module load bowtie'
func_module_add 'setenv SRNABENCH_EXE  ${INSTALL_DIR}/sRNAbench.jar'
func_module_add 'setenv SRNABENCH_LIBS ${INSTALL_DIR}/sRNAbenchDB'
func_get_package 'sRNAbench-2.0'
mv ./sRNAbench-2.0/* ${MOD_DIR}/
rm -rf sRNAbench-2.0*
# links to genomes indexes 
for igen in hg19 hg38 mm10
do
  # for bowtie and bowtie2
  for ib in ebwt bt2
  do
    # all needed files
    for ii in  1 2 3 4 rev.1 rev.2
    do
      ln -s ${DIR_ADD}/referenceGenomes/bowtie/${igen}/${igen}.${ii}.${ib} ${MOD_DIR}/sRNAbenchDB/index/${igen}.${ii}.${ib}
    done
  done
done
# links to pre-built databases
ln -s  ${DIR_ADD}/sRNAbenchDB-2.0/customIndices  ${MOD_DIR}/sRNAbenchDB/customIndices
ln -s  ${DIR_ADD}/sRNAbenchDB-2.0/libs           ${MOD_DIR}/sRNAbenchDB/libs
ln -s  ${DIR_ADD}/sRNAbenchDB-2.0/seqOBJ         ${MOD_DIR}/sRNAbenchDB/seqOBJ


# smallRNAPipeline 2.3
func_module 'smallRNAPipeline' '2.3'
func_module_add 'module load jdk/1.6'
func_module_add 'module load bowtie2'
func_module_add 'module load bowtie'
func_module_add 'module load samtools'
func_module_add 'module load sra-toolkit'
func_module_add 'module load sRNAbench'
func_module_add 'module load FastQC'
func_module_add 'module load STAR'
func_module_add 'prepend-path PATH ${INSTALL_DIR}'
func_module_add 'setenv SMALLRNA_MAKEFILE  ${INSTALL_DIR}/smallRNA_pipeline'
func_module_add 'setenv PROCESS_PIPELINE_R ${INSTALL_DIR}/processPipelineRuns.R'
func_module_add 'setenv THUNDER_EXE        ${INSTALL_DIR}/Thunder.jar'
func_get_package 'smallRNAPipeline-2.3'
mv ./smallRNAPipeline-2.3/* ${MOD_DIR}/
rm -rf smallRNAPipeline-2.3*


# exceRptPipeline 3.0
func_module 'exceRptPipeline' '3.0'
func_module_add 'module load jdk/1.6'
func_module_add 'module load bowtie2'
func_module_add 'module load bowtie'
func_module_add 'module load samtools'
func_module_add 'module load sra-toolkit'
func_module_add 'module load FastQC'
func_module_add 'module load STAR'
func_module_add 'prepend-path PATH ${INSTALL_DIR}'
func_module_add 'setenv SMALLRNA_MAKEFILE  ${INSTALL_DIR}/smallRNA_pipeline'
func_module_add 'setenv EXCERPT_DATABASE   ${INSTALL_DIR}/exceRptDB/DATABASE'
func_module_add 'setenv PROCESS_PIPELINE_R ${INSTALL_DIR}/processPipelineRuns.R'
func_module_add 'setenv THUNDER_EXE        ${INSTALL_DIR}/Thunder.jar'
func_module_add 'setenv JAVA_EXE           java'
func_get_package 'exceRptPipeline-3.0'
mv ./exceRptPipeline-3.0/* ${MOD_DIR}/
rm -rf exceRptPipeline-3.0*


# tabix
func_module_bin 'tabix' '0.2.6'
func_get_package 'tabix-0.2.6'
cd tabix-0.2.6
func_run "make all -j ${CORES_NUMBER} CFLAGS='-Wall -O3'"
mv tabix bgzip ${MOD_DIR}/bin/
cd ..
rm -rf tabix-0.2.6*


# scala 2.11.6 (needed by makeSignalChrom)
func_module_bin 'scala' '2.11'
func_module_add 'module load jdk/1.6'
func_get_package 'scala-2.11.6'
mv scala-2.11.6/bin/* ${MOD_DIR}/bin/
mv scala-2.11.6/lib   ${MOD_DIR}/
rm -rf scala-2.11.6*


# makeSignalChrom 1.2
func_module_bin 'makeSignalChrom' '1.2'
func_module_add 'module load scala'
func_get_package 'makeSignalChrom-1.2'
mv makeSignalChrom-1.2/* ${MOD_DIR}/bin/
rm -rf makeSignalChrom-1.2*


# Reasoner V2
func_module_bin 'Reasoner' '2.0'
func_get_package 'Reasoner-2.0'
mv ./Reasoner-2.0/* ${MOD_DIR}/bin/
rm -rf Reasoner-2.0*

# Reasoner V2a1
func_module_bin 'Reasoner' '2.1'
func_get_package 'Reasoner-2.1'
mv ./Reasoner-2.1/* ${MOD_DIR}/bin/
rm -rf Reasoner-2.1*

# STAR-2.4.0k
func_module_bin 'STAR' '2.4'
func_get_package 'STAR-2.4.0k'
mv STAR-STAR_2.4.0k/bin/Linux_x86_64_static/STAR ${MOD_DIR}/bin/
rm -rf STAR-STAR-2.4.0k*
ln -s  ${DIR_ADD}/STAR_indexes-2.4/ ${MOD_DIR}/indexes


# target-interaction-finder-0.1 (from 06/24/2015, last commit a73a11c1dd)
#func_module 'TargetInteractionFinder' '0.1'
#func_get_package 'target-interaction-finder-0.1'
#mv target-interaction-finder-0.1/* ${MOD_DIR}/
#rm -rf target-interaction-finder-0.1*
#cd ${MOD_DIR}/source_xgmml
#ln -s ${DIR_ADD}/TargetInteractionFinder_sourceGraphs-0.1/microcosm-hsa-2012-12-05.xgmml
#ln -s ${DIR_ADD}/TargetInteractionFinder_sourceGraphs-0.1/mirtarbase-hsa-4.4.xgmml
#ln -s ${DIR_ADD}/TargetInteractionFinder_sourceGraphs-0.1/targetscan-hsa-2012-12-05.xgmml
#cd -

# target-interaction-finder-1.0 (from the cluster)
func_module 'TargetInteractionFinder' '1.0'
func_get_package 'target-interaction-finder-1.0'
mv target-interaction-finder-1.0/* ${MOD_DIR}/
rm -rf target-interaction-finder-1.0*
cd ${MOD_DIR}/source_xgmml
ln -s ${DIR_ADD}/TargetInteractionFinder_sourceGraphs-1.0/mirtarbase-hsa-6.1.xgmml
cd -


# mirna-pathway-finder-0.1 (from 03/08/2016, last commit 8e538ba)
#func_module 'pathwayFinder' '0.1'
#func_module_add 'setenv PATHWAYFINDER ${INSTALL_DIR}/mirnapathwayfinder/__init__.py'
#func_get_package 'mirna-pathway-finder-0.1'
#mv mirna-pathway-finder-0.1/* ${MOD_DIR}/
#rm -rf mirna-pathway-finder-0.1*

# mirna-pathway-finder-1.0 (from the cluster)
func_module 'pathwayFinder' '1.0'
func_module_add 'setenv PATHWAYFINDER ${INSTALL_DIR}/mirnapathwayfinder/__init__.py'
func_get_package 'mirna-pathway-finder-1.0'
mv mirna-pathway-finder-1.0/* ${MOD_DIR}/
rm -rf mirna-pathway-finder-1.0*


# KNIFE 1.2.1 (https://github.com/lindaszabo/KNIFE/releases)
func_module 'KNIFE' '1.2.1'
func_module_add 'module load bowtie'
func_module_add 'module load bowtie2'
func_module_add 'module load samtools'
func_module_add 'prepend-path PATH ${INSTALL_DIR}'
func_module_add 'prepend-path PATH ${INSTALL_DIR}/analysis'
func_module_add 'prepend-path PATH ${INSTALL_DIR}/denovo_scripts'
func_module_add 'prepend-path PATH ${INSTALL_DIR}/qualityStats'
func_module_add 'setenv CIRCRNA_SCRIPT ${INSTALL_DIR}/findCircularRNA.sh'
func_module_add 'setenv CIRCRNA_COMPLETE_SCRIPT ${INSTALL_DIR}/completeRun.sh'
func_module_add 'setenv CIRCRNA_INDEX ${INSTALL_DIR}/index'
func_get_package 'KNIFE-1.2.1'
patch -p0 < KNIFE-1.2.1_changes.patch
cp -r KNIFE-1.2.1/circularRNApipeline_Standalone/* ${MOD_DIR}/
chmod +x ${MOD_DIR}/ParseFastQ.py  ${MOD_DIR}/analysis/predictJunctions_tableData.r
chmod +x ${MOD_DIR}/qualityStats/getUnalignedReadCount.py  ${MOD_DIR}/qualityStats/ParseFastQ.py
rm -rf KNIFE-1.2.1*

