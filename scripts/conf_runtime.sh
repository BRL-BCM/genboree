
set +v

# runtime environment for Genboree

source ${DIR_SCRIPTS}/conf_global.sh

export PS1='genboree_runtime_env$ '

export RUBYOPT=' -r rubygems '
export RUBYLIB=${DIR_TARGET}/lib/ruby/site_ruby/1.8:${DIR_TARGET}/home/lib
export DOMAIN_ALIAS_FILE=${DIR_DATA}/conf/domainAliases.json
export PATH=${DIR_TARGET}/bin:${DIR_TARGET}/jdk/bin:${DIR_TARGET}/mysql/bin:${DIR_TARGET}/mongodb/bin:${PATH}
export LD_LIBRARY_PATH=${DIR_TARGET}/lib:${R_HOME}/lib:${DIR_TARGET}/apache/apr/lib:${DIR_TARGET}/mysql/lib:${LD_LIBRARY_PATH}
# svn://histidine.brl.bcmd.bcm.edu/brl-repo/PATCH_NOTES/genboree/2015-09-08.virtualFtpImplementation
export TMPDIR=${DIR_TARGET}/tmp

# API key for OMIM
export OMIM_API_KEY=__GENBOREE_omimApiKey__
# API key for bioPortal
export BIOPORTAL_API_KEY=__GENBOREE_bioPortalApiKey__

# svn://histidine.brl.bcmd.bcm.edu/brl-repo/PATCH_NOTES/genboree/2015-08-13.snifferMove
export SNIFFER_CONF_FILE=${DIR_TARGET}/conf/snifferFormatInfo.json

if [ -e ${DIR_TARGET}/Modules/default/init/bash ]
then
    source ${DIR_TARGET}/Modules/default/init/bash
fi
