#!/bin/bash

set -e  # stop on first error
set -u  # stop when tries to use uninitialized variable

DIR_SCRIPTS="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"   # directory with scripts
source ${DIR_SCRIPTS}/conf_build.sh

set -v  # print commands

# copy default data content, contains:
# - conf - configuration files specific for installation
# - ssl - SSL certificates used by NGINX
# - genboree/ridSequences - directory for sequences
# - genboree/KB - svn://histidine.brl.bcmd.bcm.edu/brl-repo/PATCH_NOTES/genboree/2015-02-11.migrateToCastValuesInKB
# - genboree/files/grp - svn://histidine.brl.bcmd.bcm.edu/brl-repo/PATCH_NOTES/genboree/2015-03-12.wideReachingRestDataEntityAndKBChanges
cp -r ${DIR_SRC}/data  ${DIR_DATA}

# mysql
mkdir -p ${DIR_DATA}/mysql/data
mkdir -p ${DIR_DATA}/mysql/scripts
mkdir -p ${DIR_DATA}/mysql/partitioned  # svn://histidine.brl.bcmd.bcm.edu/brl-repo/PATCH_NOTES/genboree/2016-02-04.redmineMaps
cp ${DIR_SRC}/sql/* ${DIR_DATA}/mysql/scripts/

# mongodb
mkdir -p ${DIR_DATA}/mongodb/data
mkdir -p ${DIR_DATA}/mongodb/scripts
cp ${DIR_SRC}/mongo_js/* ${DIR_DATA}/mongodb/scripts/

# redmine
mkdir -p ${DIR_DATA}/redmine/files
cp -r ${DIR_SRC}/website_images/* ${DIR_DATA}/redmine/files/

#6)  Setup installation directories. Create the following directories:
mkdir -p ${DIR_DATA}/genboree/temp
mkdir -p ${DIR_DATA}/tmp/mysql
mkdir -p ${DIR_DATA}/tmp/thin


#9) Setup symbolic links to directories under /usr/local/brl/data under Apache's htdocs
mkdir -p ${DIR_DATA}/genboree/gallery
mkdir -p ${DIR_DATA}/genboree/genboreeUploads
mkdir -p ${DIR_DATA}/genboree/genboreeDownloads


# SSL stuff (Kafka - 2018-01-05.sslKeypairSetup)
chmod 755 $SSL_BASE_DIR
chmod g+s $SSL_BASE_DIR
# Subdir for public key ("cert") of your CA. Even non-CA machines need this.
chmod 755 $SSL_BASE_DIR/ca/pub/
# Subdir for Java KeyStore .jks and derived files:
chmod 2750 $SSL_BASE_DIR/jks/
# Subdir for incoming Certificate Signing Requests (CSRs) and the signed results.
chmod 2750 $SSL_BASE_DIR/csrs/
# Subdir for the PRIVATE key file for your CA.
chmod 0700 $SSL_BASE_DIR/ca/priv/

