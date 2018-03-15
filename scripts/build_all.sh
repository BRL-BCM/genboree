#!/bin/bash

set -e  # stop on first error
set -u  # stop when tries to use uninitialized variable

DIR_SCRIPTS="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"   # directory with scripts
source ${DIR_SCRIPTS}/conf_build.sh

rm -rf ${DIR_TARGET} ${DIR_DATA}

date
echo "=================== START ================"
PACKAGE_NAME="genboree-${GENB_VERSION}"
mkdir   ${PACKAGE_NAME}
mkdir ./${PACKAGE_NAME}/docs
cp ../docs/installation.pdf ./${PACKAGE_NAME}/docs/
cp ./conf_global.sh ./conf_runtime.sh ./install.sh ./upgrade.sh ../License.txt ./${PACKAGE_NAME}/
# ---- build base libs
./build_libs.sh "$@"
./build_R_packages.sh "$@"
./build_modules.sh "$@"
./build_gems.sh "$@"
./build_servers.sh "$@"
# ---- set license
func_run "./add_header.rb  ../header.txt  ../src/"
# ---- build the rest of components
./build_data.sh  "$@"
./build_final.sh "$@"
./build_redmine.sh "$@"
# ---- Make a final package
mv ${DIR_TARGET} ./local
mv ${DIR_DATA}   ./data
tar czf ${PACKAGE_NAME}/local.tgz local
tar czf ${PACKAGE_NAME}/data.tgz  data
rm -rf local data
tar cf ${PACKAGE_NAME}.tar ${PACKAGE_NAME}
echo "==================== END ================="
date
