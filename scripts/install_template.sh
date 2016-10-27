#!/bin/bash

set -e  # stop on first error
set -u  # stop when tries to use uninitialized variable

if [ "${USER}" != "genboree" ]
then
    echo "This script can be run by genboree user only."
    exit 1
fi 

DIR_SCRIPTS="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"   # directory with scripts
source ${DIR_SCRIPTS}/conf_runtime.sh

set -v  # print commands


TEMPLATE=${1}
DIR_TEMP=dir_$(basename ${TEMPLATE})

mkdir ${DIR_TEMP}

tar xf ${TEMPLATE} -C ${DIR_DATA}/genboree/ridSequences     --wildcards 'genboree_r*'
tar xf ${TEMPLATE} -C ./${DIR_TEMP}                         --wildcards 'tmp_*.sql'

cd ./${DIR_TEMP}
GENOME_NAME=`ls tmp_*_db.sql`
GENOME_NAME=${GENOME_NAME:4:-7}
cd -

mysql --defaults-file=${DIR_TARGET}/etc/my.cnf -u root < ./${DIR_TEMP}/tmp_*_db.sql
mysql --defaults-file=${DIR_TARGET}/etc/my.cnf -u root < ./${DIR_TEMP}/tmp_*_main.sql

rm -rf ${DIR_TEMP}
