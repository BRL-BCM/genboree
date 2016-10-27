#!/bin/bash

set -e  # stop on first error
set -u  # stop when tries to use uninitialized variable

DIR_SCRIPTS="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"   # directory with scripts
source ${DIR_SCRIPTS}/conf_build.sh

set -v  # print commands

# packages from http://cran.r-project.org/web/packages/available_packages_by_name.html

# R libs) RColorBrewer
func_get_package "RColorBrewer_1.0-5"
func_run "R CMD INSTALL RColorBrewer"
rm -rf RColorBrewer*

# R libs) bitopts
func_get_package "bitops_1.0-6"
func_run "R CMD INSTALL bitops"
rm -rf bitops*

# R libs) caTools
func_get_package "caTools_1.17"
func_run "R CMD INSTALL caTools"
rm -rf caTools*

# R libs) gtools
func_get_package "gtools_3.4.0"
func_run "R CMD INSTALL gtools"
rm -rf gtools*

# R libs) gdata
func_get_package "gdata_2.13.3"
func_run "R CMD INSTALL gdata"
rm -rf gdata*

# R libs) gplots
func_get_package "gplots_2.10.1"
func_run "R CMD INSTALL gplots"
rm -rf gplots*

# R libs) hybridHclust
func_get_package "hybridHclust_1.0-4"
func_run "R CMD INSTALL hybridHclust"
rm -rf hybridHclust*

# R libs) amap
func_get_package "amap_0.8-12"
func_run "R CMD INSTALL amap"
rm -rf amap*

# R libs) corrplot
func_get_package "corrplot_0.73"
func_run "R CMD INSTALL corrplot"
rm -rf corrplot*

# R libs) Cairo
func_get_package "Cairo_1.5-5"
func_run "R CMD INSTALL Cairo"
rm -rf Cairo*

# R libs) randomForest
func_get_package "randomForest_4.6-7"
func_run "R CMD INSTALL randomForest"
rm -rf randomForest*

# R libs) Formula
func_get_package "Formula_1.1-1"
func_run "R CMD INSTALL Formula"
rm -rf Formula*

# R libs) latticeExtra
func_get_package "latticeExtra_0.6-26"
func_run "R CMD INSTALL latticeExtra"
rm -rf latticeExtra*

# R libs) Hmisc (needs survival 2.37.6)
#func_get_package "Hmisc_3.14-4"
#func_run "R CMD INSTALL Hmisc"
#rm -rf Hmisc*

# R libs) rFerns
func_get_package "rFerns_0.3.3"
func_run "R CMD INSTALL rFerns"
rm -rf rFerns*

# R libs) Boruta
func_get_package "Boruta_3.0.0"
func_run "R CMD INSTALL Boruta"
rm -rf Boruta*

# R libs) mlbench
func_get_package "mlbench_2.1-1"
func_run "R CMD INSTALL mlbench"
rm -rf mlbench*

# Needed by Alpha diversity, they need tk
# R libs) tcltk2_1.2-10
#func_get_package "tcltk2_1.2-10"
#func_run "R CMD INSTALL tcltk2"
#rm -rf tcltk2*
# R libs) Rcmdr_2.0-4
#func_get_package "Rcmdr_2.0-4"
#func_run "R CMD INSTALL Rcmdr"
#rm -rf Rcmdr*
# R libs) BiodiversityR_2.4-4
#func_get_package "BiodiversityR_2.4-4"
#func_run "R CMD INSTALL BiodiversityR"
#rm -rf BiodiversityR*

# mvtnorm - needed by coin
func_get_package "mvtnorm_1.0-0"
func_run "R CMD INSTALL mvtnorm"
rm -rf mvtnorm*

# modeltools - needed by coin
func_get_package "modeltools_0.2-21"
func_run "R CMD INSTALL modeltools"
rm -rf modeltools*

# coin - needed by lefse
func_get_package "coin_1.0-23"
func_run "R CMD INSTALL coin"
rm -rf coin*


# for R 2.15 - packages from http://bioconductor.org/packages/2.11/bioc/

# R libs) ctc
#func_get_package "ctc_1.32.0"
#func_run "R CMD INSTALL ctc"
#rm -rf ctc*

# R libs) DNAcopy
#func_get_package "DNAcopy_1.32.0"
#func_run "R CMD INSTALL DNAcopy"
#rm -rf DNAcopy*

# R libs) BiocGenerics
#func_get_package "BiocGenerics_0.4.0"
#func_run "R CMD INSTALL BiocGenerics"
#rm -rf BiocGenerics*

# R libs) Biobase
#func_get_package "Biobase_2.18.0"
#func_run "R CMD INSTALL Biobase"
#rm -rf Biobase*

# R libs) multtest
#func_get_package "multtest_2.14.0"
#func_run "R CMD INSTALL multtest"
#rm -rf multtest*

# R libs) aCGH
#func_get_package "aCGH_1.36.0"
#func_run "R CMD INSTALL aCGH"
#rm -rf aCGH*

# R libs) preprocessCore
#func_get_package "preprocessCore_1.20.0"
#func_run "R CMD INSTALL preprocessCore"
#rm -rf preprocessCore*

# R libs) limma
#func_get_package "limma_3.14.4"
#func_run "R CMD INSTALL limma"
#rm -rf limma*



# for R 3.1 - packages from http://bioconductor.org/packages/2.14/bioc/

# R libs) ctc
func_get_package "ctc_1.38.0"
func_run "R CMD INSTALL ctc"
rm -rf ctc*

# R libs) DNAcopy
func_get_package "DNAcopy_1.38.1"
func_run "R CMD INSTALL DNAcopy"
rm -rf DNAcopy*

# R libs) BiocGenerics
func_get_package "BiocGenerics_0.10.0"
func_run "R CMD INSTALL BiocGenerics"
rm -rf BiocGenerics*

# R libs) Biobase
func_get_package "Biobase_2.24.0"
func_run "R CMD INSTALL Biobase"
rm -rf Biobase*

# R libs) multtest
func_get_package "multtest_2.20.0"
func_run "R CMD INSTALL multtest"
rm -rf multtest*

# R libs) aCGH
func_get_package "aCGH_1.42.0"
func_run "R CMD INSTALL aCGH"
rm -rf aCGH*

# R libs) preprocessCore
func_get_package "preprocessCore_1.26.1"
func_run "R CMD INSTALL preprocessCore"
rm -rf preprocessCore*

# R libs) limma
func_get_package "limma_3.20.4"
func_run "R CMD INSTALL limma"
rm -rf limma*


# 2015-03-27.reasonerV2
# R libs) jsonlite
func_get_package "jsonlite_0.9.15"
func_run "R CMD INSTALL jsonlite"
rm -rf jsonlite*

