#!/bin/bash

set -e  # stop on first error
set -u  # stop when tries to use uninitialized variable

DIR_SCRIPTS="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"   # directory with scripts
source ${DIR_SCRIPTS}/conf_build.sh


set -v  # print commands

# copy Redmine from src
mkdir -p ${DIR_TARGET}/rails
cp -R ${DIR_SRC}/redmine  ${DIR_TARGET}/rails/
mkdir ${DIR_TARGET}/var/redmine
mkdir -p ${DIR_TARGET}/tmp/redmine/pdf
ln -s  ../../var/redmine  ${DIR_TARGET}/rails/redmine/var
ln -s  ../../tmp/redmine  ${DIR_TARGET}/rails/redmine/tmp
ln -s  ../../../data/redmine/files  ${DIR_TARGET}/rails/redmine/files
find ${DIR_TARGET}/rails/redmine -type d -exec chmod 2775 {} \;
find ${DIR_TARGET}/rails/redmine -type f -exec chmod  660 {} \;
chmod 640 ${DIR_TARGET}/rails/redmine/config/database.yml

# create Gemfile.lock
cd ${DIR_TARGET}/rails/redmine
func_run "bundle install --local --without development test"
cd -

# website
cp -R ${DIR_SRC}/website  ${DIR_TARGET}/
