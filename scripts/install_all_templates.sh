#!/bin/bash

set -e  # stop on first error
set -u  # stop when tries to use uninitialized variable
set -v  # print commands

# path to directory with templates
DIR_TEMPLATES=../data

# install all templates by default
# you can comment out here templates you do not need
./install_template.sh ${DIR_TEMPLATES}/tmp_canFam2.tgz
./install_template.sh ${DIR_TEMPLATES}/tmp_dm5.1.tgz
./install_template.sh ${DIR_TEMPLATES}/tmp_hg18.tgz
./install_template.sh ${DIR_TEMPLATES}/tmp_hg19.tgz
./install_template.sh ${DIR_TEMPLATES}/tmp_mm8.tgz
./install_template.sh ${DIR_TEMPLATES}/tmp_mm9.tgz
./install_template.sh ${DIR_TEMPLATES}/tmp_panTro2.tgz
./install_template.sh ${DIR_TEMPLATES}/tmp_rheMac2.tgz
./install_template.sh ${DIR_TEMPLATES}/tmp_rn3.1.tgz
