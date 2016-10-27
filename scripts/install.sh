#!/bin/bash

set -e  # stop on first error
set -u  # stop when tries to use uninitialized variable

DIR_SCRIPTS="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"   # directory with scripts
source ${DIR_SCRIPTS}/conf_runtime.sh

#set -v  # print commands

echo "Check if locations ${DIR_TARGET} and ${DIR_DATA} are free..."
if [ -e ${DIR_TARGET} ] || [ -e ${DIR_DATA} ]; then
	echo "At least one of the location above exists. You have to remove old Genboree below install the new one or use upgrade.sh script to migrate to the new version. Installation aborted.";
else
	echo "OK, none of them exists.";
fi

echo "Check if user genboree exists..."
if [ `cat /etc/passwd | grep '^genboree:'` ]; then
	echo "YES";
else
	echo "NO, creating user.";
	# create genboree user 
	useradd --home ${DIR_TARGET}/home --shell /bin/bash --system  genboree;
fi


# ---- unpack genboree package
echo "Copy Genboree to target location..."
mkdir -p ${DIR_TARGET}
mkdir -p ${DIR_DATA}
mkdir -p ${DIR_ADD}
tar xzf ${DIR_SCRIPTS}/local.tgz -C ${DIR_TARGET} --wildcards 'local/*' --strip-components=1
tar xzf ${DIR_SCRIPTS}/data.tgz  -C ${DIR_DATA}   --wildcards 'data/*'  --strip-components=1


# ---- Setup more file & directories permissions 
echo "Set ownership and access rights..."
chown -R genboree:genboree  ${DIR_BRL}
chmod 600        ${DIR_TARGET}/etc/.dbrc
chmod 750 -R     ${DIR_TARGET}/etc/init.d
chmod 740        ${INLINEDIR}

# ---- create MySQL database
echo "Prepare MYSQL databases management system ..."
cd ${DIR_TARGET}/mysql
./scripts/mysql_install_db --defaults-file=${DIR_TARGET}/etc/my.cnf
cd -

#func_run "${DIR_TARGET}/mysql/bin/mysql_secure_installation"

echo "Start MYSQL daemon ..."
${DIR_TARGET}/etc/init.d/mysqld_init start

echo "Create Genboree databases..."
mysql --defaults-file=${DIR_TARGET}/etc/my.cnf -u root < ${DIR_DATA}/mysql/scripts/create_users.sql
mysql --defaults-file=${DIR_TARGET}/etc/my.cnf -u root < ${DIR_DATA}/mysql/scripts/genboree_schema.sql
mysql --defaults-file=${DIR_TARGET}/etc/my.cnf -u root < ${DIR_DATA}/mysql/scripts/prequeue_schema.sql
mysql --defaults-file=${DIR_TARGET}/etc/my.cnf -u root < ${DIR_DATA}/mysql/scripts/cache_schema.sql
mysql --defaults-file=${DIR_TARGET}/etc/my.cnf -u root < ${DIR_DATA}/mysql/scripts/initial_conf.sql
mysql --defaults-file=${DIR_TARGET}/etc/my.cnf -u root < ${DIR_DATA}/mysql/scripts/redmine.sql

echo "Redmine installation..."
cd ${DIR_TARGET}/rails/redmine
rake generate_secret_token
RAILS_ENV=production rake db:migrate
RAILS_ENV=production REDMINE_LANG=en rake redmine:load_default_data
RAILS_ENV=production ruby script/rails runner 'AuthSourceGenboree.create( {
  :type               => "AuthSourceGenboree",
  :name               => "Genboree",
  :host               => "localhost",
  :port               => 16002,
  :account            => "genboree",
  :account_password   => "genboree",
  :base_dn            => "mysql:genboree",
  :attr_login         => "name",
  :attr_firstname     => "firstName",
  :attr_lastname      => "lastName",
  :attr_mail          => "email",
  :onthefly_register  => true,
  :tls                => false
})'
RAILS_ENV=production rake redmine:plugins
cd -

echo "Create redmine database ..."
mysql --defaults-file=${DIR_TARGET}/etc/my.cnf -u root < ${DIR_DATA}/mysql/scripts/redmine_conf.sql
mysql --defaults-file=${DIR_TARGET}/etc/my.cnf -u root < ${DIR_DATA}/mysql/scripts/redmine_website.sql
mysql --defaults-file=${DIR_TARGET}/etc/my.cnf -u root < ${DIR_DATA}/mysql/scripts/redmine_default_website.sql
mysql --defaults-file=${DIR_TARGET}/etc/my.cnf -u root < ${DIR_DATA}/mysql/scripts/redmine_set_autoincrement.sql

echo "Stop MYSQL daemon ..."
${DIR_TARGET}/etc/init.d/mysqld_init stop


echo "MongoDB initialization..."
${DIR_TARGET}/etc/init.d/mongodb_init start
mongo --port 16001 < ${DIR_DATA}/mongodb/scripts/genboree.js
${DIR_TARGET}/etc/init.d/mongodb_init stop

echo "Set ownership once more time..."
chown -R genboree:genboree  ${DIR_BRL}
