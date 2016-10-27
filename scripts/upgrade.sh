#!/bin/bash

set -e  # stop on first error
set -u  # stop when tries to use uninitialized variable

DIR_SCRIPTS="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"   # directory with scripts
source ${DIR_SCRIPTS}/conf_runtime.sh

#set -v  # print commands

echo "Check if location ${DIR_DATA} exists..."
if [ -e ${DIR_DATA} ]; then
    echo "OK, it exists.";
else
    echo "It does not exists. You need old Genboree to run upgrade procedure. Upgrade is aborted.";
fi

echo "You have to stop Genboree. Can I continue? [y/n]"
read ANSWER
if [ "${ANSWER}" != "y" ]; then
    echo "Upgrade cancelled by user. Exiting."
    exit 1
fi

echo "Check if location ${DIR_TARGET} exists ..."
if [ -e ${DIR_TARGET} ]; then
    DATETIME=`date '+%Y%m%d_%H%M%S'`
    echo "It exists. I am moving it to ${DIR_TARGET}_${DATETIME} ..."
    mv ${DIR_TARGET} ${DIR_TARGET}_${DATETIME}
    echo "OK"
else
    echo "OK. It does not exist."
fi

# ---- unpack genboree package
echo "Copy Genboree to target location..."
mkdir -p ${DIR_TARGET}
tar xzf ${DIR_SCRIPTS}/local.tgz -C ${DIR_TARGET} --wildcards 'local/*' --strip-components=1

# ---- Setup more file & directories permissions 
echo "Set ownership and access rights..."
chown -R genboree:genboree  ${DIR_BRL}
chmod 600        ${DIR_TARGET}/etc/.dbrc
chmod 750 -R     ${DIR_TARGET}/etc/init.d
chmod 740        ${INLINEDIR}

# ---- Start daemons
echo "Start MYSQL daemon ..."
${DIR_TARGET}/etc/init.d/mysqld_init start
echo "Start MongoDB daemon ..."
${DIR_TARGET}/etc/init.d/mongodb_init start

# ---- upgrade
echo "Redmine upgrade..."
cd ${DIR_TARGET}/rails/redmine
RAILS_ENV=production rake generate_secret_token
RAILS_ENV=production rake db:migrate
RAILS_ENV=production rake redmine:plugins
cd -

# ---- stop daemons
echo "Stop MongoDB daemon ..."
${DIR_TARGET}/etc/init.d/mongodb_init stop
echo "Stop MYSQL daemon ..."
${DIR_TARGET}/etc/init.d/mysqld_init stop


echo "Set ownership once more time..."
chown -R genboree:genboree  ${DIR_BRL}

echo "You have to run correct migrations by hand now!!!"
