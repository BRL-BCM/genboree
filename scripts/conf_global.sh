

export DIR_BRL="/usr/local/brl"
export DIR_TARGET="/usr/local/brl/local"   # target direcory (must match directory on a target server)
export DIR_DATA="/usr/local/brl/data"      # directory with data (must match directory on a target server)
export DIR_ADD="/usr/local/brl/additional" # directory with additional data


# environment variables used in the script (set to null if unset)
TMP=${PATH:=}
TMP=${LD_LIBRARY_PATH:=}


export PKG_CONFIG_PATH=${DIR_TARGET}/lib/pkgconfig

# Java
export JAVA_HOME=${DIR_TARGET}/jdk
export CATALINA_HOME=${DIR_TARGET}/apache/htdocs
export CLASSPATH=${CATALINA_HOME}/common/lib/servlet-api.jar:${CATALINA_HOME}/common/lib/mysql-connector-java.jar:${CATALINA_HOME}/common/lib/activation.jar:${CATALINA_HOME}/common/lib/mail.jar:${DIR_TARGET}/apache/java-bin/WEB-INF/lib/GDASServlet.jar:${CATALINA_HOME}/common/lib/commons-codec-1.6.jar

# R
export R_HOME=${DIR_TARGET}/lib/R

# Rails (Redmine)
export RAILS_ENV=production

# Genboree
export DBRC_FILE=${DIR_TARGET}/etc/.dbrc
export GENB_CONFIG=${DIR_TARGET}/conf/genboree.config.properties
export INLINEDIR=${DIR_TARGET}/lib/ruby_inline
export NETWORK_SCRATCH=/usr/local/brl/scratch

# SSL stuff (Kafka - 2018-01-05.sslKeypairSetup)
export SSL_BASE_DIR=/usr/local/brl/data/var/ssl

