#!/bin/bash

set -e  # stop on first error
set -u  # stop when tries to use uninitialized variable

DIR_SCRIPTS="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"   # directory with scripts
source ${DIR_SCRIPTS}/conf_build.sh

rm -rf ${DIR_TARGET} ${DIR_DATA}

date
echo "=================== START ================"
# ---- build base libs
./build_libs.sh "$@"
./build_R_packages.sh "$@"
./build_modules.sh "$@"
./build_gems.sh "$@"
./build_servers.sh "$@"
# ---- set license
func_run "./add_header.rb  ../src/header.txt  ../src/"
cp ../src/license.txt  ../src/agpl-3.0.txt  ${DIR_TARGET}
# ---- build the rest of components
./build_data.sh  "$@"
./build_final.sh "$@"
./build_redmine.sh "$@"
# ---- remove .svn directories
find ${DIR_TARGET} -type d -name .svn -exec rm -rf {} \;  || true
find ${DIR_DATA}   -type d -name .svn -exec rm -rf {} \;  || true
# ---- Make a final package
mv ${DIR_TARGET} ./local
mv ${DIR_DATA}   ./data
PACKAGE_NAME="genboree-${GENB_VERSION}"
mkdir   ${PACKAGE_NAME}
tar czf ${PACKAGE_NAME}/local.tgz local
tar czf ${PACKAGE_NAME}/data.tgz  data
rm -rf local data
cp ./conf_global.sh ./conf_runtime.sh ./install.sh ./upgrade.sh ../src/license.txt ../src/agpl-3.0.txt ./${PACKAGE_NAME}/
mkdir ./${PACKAGE_NAME}/docs
cp ../docs/HowToInstall.pdf ./${PACKAGE_NAME}/docs/
tar cf ${PACKAGE_NAME}.tar ${PACKAGE_NAME}
echo "==================== END ================="
date
