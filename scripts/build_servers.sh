#!/bin/bash

set -e  # stop on first error
set -u  # stop when tries to use uninitialized variable

DIR_SCRIPTS="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"   # directory with scripts
source ${DIR_SCRIPTS}/conf_build.sh

set -v  # print commands


#if false; then  # debug

# ======================== NGINX
func_get_package "nginx-1.10.1"
func_get_package "nginx-upload-module-2.2_5Dec2014"
func_get_package "nginx-upload-progress-module-0.9.1"
func_get_package "ngx_cache_purge-2.3"
cd nginx-1.10.1
func_run "CFLAGS=' -O3 ' ./configure
--prefix=${DIR_TARGET}/nginx
--with-pcre
--with-http_ssl_module
--with-http_addition_module
--with-http_sub_module
--with-http_stub_status_module
--with-http_dav_module
--without-http_ssi_module
--without-http_userid_module
--without-http_geo_module
--without-http_charset_module
--without-http_split_clients_module
--without-http_fastcgi_module
--without-http_uwsgi_module
--without-http_scgi_module
--without-http_memcached_module
--without-http_browser_module
--add-module=../nginx-upload-module-2.2_5Dec2014
--add-module=../nginx-upload-progress-module-0.9.1
--add-module=../ngx_cache_purge-2.3"
func_run "make -j ${CORES_NUMBER}"
mkdir -p ${DIR_TARGET}/nginx
func_run "make install"
cd ..
rm -rf nginx-* ngx_cache_purge-*
ln -s ../apache/htdocs ${DIR_TARGET}/nginx/htdocs

#4) Configure Nginx for your server
#- If you'll be configuring the HTTPS server, then you will need to make some SSL certificates and put the appropriate
#files in .../nginx/conf/. Current recommendation is to remove the HTTPS-related
#server{} object and the include of ssl.conf in the reference conf file.
#. Instructions: http://tajidyakub.com/2008/07/27/https-ssl-and-nginx/
#. Steps:
#. openssl genrsa -des3 -out cert.key 1024
#. openssl req -new -key cert.key -out cert.csr
#. cp cert.key cert.key.original
#. openssl rsa -in cert.key.original -out cert.key
#. openssl x509 -req -days 365 -in cert.csr -signkey cert.key -out cert.crt
#. chmod 670 cert.*
#. chgrp nobody . *


  #7) Prep the Upload Module's temp Dir Tree   TODO 
    #- For the "upload_store" directive in the nginx.genboree.conf, use:
          #upload_store /usr/local/brl/data/tmp/nginx/upload_temp 1 1 1 ;
  #8) If possible, use a working server for reference with regards to the nginx.genboree.conf.
    #It will have additional proxy targets, new features like handling of "location ~ ^/genbUpload/.*"
    #and doing upload progress bars, etc.
    
#1) Create/Update official link to deployed Nginx and a tmp dir
mkdir -p ${DIR_TARGET}/tmp/nginx/client_body_temp
mkdir -p ${DIR_TARGET}/tmp/nginx/proxy_temp
mkdir -p ${DIR_TARGET}/tmp/nginx/fastcgi_temp
mkdir -p ${DIR_TARGET}/tmp/nginx/cache

#7) Prep the Upload Module's temp Dir Tree
#- Unlike for core nginx temp dirs, the Upload Module oddly does not auto-create the temp dir tree resulting from the multi-level hashing.
#- So you need to pre-create the tree yourself. Say, as root, do:
for xx in 1 2 3 4 5 6 7 8 9 0; do
  for yy in 1 2 3 4 5 6 7 8 9 0; do
    for ww in 1 2 3 4 5 6 7 8 9 0; do
      mkdir -p ${DIR_TARGET}/tmp/nginx/upload_temp/$xx/$yy/$ww
    done
  done
done

# nginx logs are moved to data
ln -s ../../data/var/nginx_access.log  ${DIR_TARGET}/var/
ln -s ../../data/var/nginx_error.log   ${DIR_TARGET}/var/

#-------------------------------------------------------------------------- TODO - skip for now
#E. Install MYSQL
#================
  #0) Note: if you are using Percona's MySQL as mentioned above, DO NOT also install
    #an Oracle MySQL. Point ${DIR_TARGET}/mysql -> {specific Percona install} and
    #then make all the usual softlinks and such as described below.
    #0.1) DO NOT use "skip-innodb" in your my.cnf with Percona's MySQL. It won't start without
      #innodb plugin loaded.
    #0.2) If you run the mysql CLIENT as root user, make sure to explicitly use ours
      #(${DIR_TARGET}/mysql/bin/mysql) and not the default OS one. Else it will fail.
    #0.3) Note that it would be best to copy a my.cnf from an existing Genboree MySQL server and
      #use that as the basis for setting up yours--adjusting any memory settings and such accordingly.

#1) Installation
#^^^^^^^^^^^^^^^
mkdir -p ${DIR_TARGET}/mysql
mkdir -p ${DIR_TARGET}/tmp/mysql
func_get_package "percona-server-5.6.16-64.0"
cd percona-server-5.6.16-64.0
mkdir my_build
cd my_build

     #1.1.1) Make sure the nr_requests and elevator I/O fixes are applied (see top of this file) - TODO


#1.2) Configure mysql (replace version info for prefix):
func_run "cmake .. 
-DCMAKE_BUILD_TYPE=Release
-DCMAKE_INSTALL_PREFIX=${DIR_TARGET}/mysql
-DCMAKE_VERBOSE_MAKEFILE=ON
-DMANUFACTURER=Genboree
-DMYSQL_DATADIR=${DIR_DATA}/mysql/data
-DENABLED_LOCAL_INFILE=ON
-DWITH_ARCHIVE_STORAGE_ENGINE=ON
-DWITH_DEBUG=OFF
-DWITH_EMBEDDED_SERVER=OFF
-DWITH_INNOBASE_STORAGE_ENGINE=ON
-DWITH_PARTITION_STORAGE_ENGINE=ON
-DWITH_PERFSCHEMA_STORAGE_ENGINE=ON
-DWITH_PIC=ON
-DCURSES_NCURSES_INCLUDE_PATH=${DIR_TARGET}/include
-DCURSES_INCLUDE_PATH=${DIR_TARGET}/include
-DCURSES_NCURSES_LIBRARY=${DIR_TARGET}/lib/libncursesw.so
-DSYSCONFDIR=${DIR_TARGET}/etc
-DMYSQL_UNIX_ADDR=${DIR_TARGET}/var/mysql.sock
-DCMAKE_POLICY_DEFAULT_CMP0026=\"OLD\"
"
# use -DMYSQL_TCP_PORT_DEFAULT and -DMYSQL_TCP_PORT to set TCP port
# socket (MYSQL_UNIX_ADDR) must be set here, in other case mysql2 ruby module doesn't work properly
func_run "make -j ${CORES_NUMBER}"
func_run_test "make test"
func_run "make install"
ln -s libperconaserverclient.so.18.1.0  ${DIR_TARGET}/mysql/lib/libmysqlclient.so   # they changed name of the libmysqlclient library..., needed by jimKent
cd ../..
rm -rf percona-server-5.6.16-64.0*



#8) Ruby DB Support Libs:
#^^^^^^^^^^^^^^^^^^^^^^^^^^
#8.1) mysql-ruby
func_get_package "mysql-ruby-2.8.2"
cd mysql-ruby-2.8.2
func_run "ruby extconf.rb --with-mysql-config=${DIR_TARGET}/mysql/bin/mysql_config" #--with-mysql-include=${DIR_TARGET}/mysql/include --with-mysql-lib=${DIR_TARGET}/mysql/lib"
func_run "make"
func_run "make install"
cd ..
rm -rf mysql-ruby-2.8.2*
# empty mysql gem to satisfy dbd-mysql-0.4.4
func_get_package "mysql.gemspec"
func_run "gem build mysql.gemspec"
func_run "gem install --local mysql-2.8.22.gem"
rm  mysql.gemspec  mysql-2.8.22.gem


#8.2) mysql2
func_get_package "mysql2-0.3.15"
func_run "gem install --local mysql2-0.3.15.gem -- --with-mysql-config=${DIR_TARGET}/mysql/bin/mysql_config" # --with-mysql-dir=${DIR_TARGET}/mysql"
rm mysql2-0.3.15*


#8.3) ruby-dbi
func_gem "deprecated-2.0.1"

# problem with conflict on binaries (with rails-dbi) - we chose binaries from rails-dbi
mv ${DIR_TARGET}/bin/dbi              ${DIR_TARGET}/bin/dbi_from_rails-dbi
mv ${DIR_TARGET}/bin/test_broken_dbi  ${DIR_TARGET}/bin/test_broken_dbi_from_rails-dbi
func_gem "dbi-0.4.5"
mv ${DIR_TARGET}/bin/dbi              ${DIR_TARGET}/bin/dbi_from_dbi
mv ${DIR_TARGET}/bin/test_broken_dbi  ${DIR_TARGET}/bin/test_broken_dbi_from_dbi
ln -s dbi_from_rails-dbi              ${DIR_TARGET}/bin/dbi              
ln -s test_broken_dbi_from_rails-dbi  ${DIR_TARGET}/bin/test_broken_dbi  

func_get_package "dbd-mysql-0.4.4"
func_run "gem install --local dbd-mysql-0.4.4.gem"
#8.3.2) Regardless, check the mysql DBD database.rb code has a working quote()
#method! In some recent versions, this method was commented out or removed
#(also in the Postgres DBD; folks are complaining).
mv ${DIR_TARGET}/lib/ruby/gems/1.8/gems/dbd-mysql-0.4.4/lib/dbd/mysql/database.rb .
patch -p1 < dbd-mysql-0.4.4_quote.patch
mv database.rb ${DIR_TARGET}/lib/ruby/gems/1.8/gems/dbd-mysql-0.4.4/lib/dbd/mysql/
#8.4) Furthermore, we have discoved a very bad INCOMPATIBILITY change in
#newer versions of the dbd-mysql gem that changes completely how Ruby's
#Time obejct is converted into an SQL value for insertion. Very bad.
# ARJ: WHAT?? The following is NOT how it worked previously and NOT what Ruby's Time can store.
# It can store FULL DATE INFORMATION. Thus: 2 x moronic: break compatibility and lose
# info previously able to capture. Bad API design decisions.
# PPP: looks like total mess with time format, may be also connected with the patch dbd-mysql-0.4.4_quote.patch
mv ${DIR_TARGET}/lib/ruby/gems/1.8/gems/dbd-mysql-0.4.4/lib/dbd/Mysql.rb .
patch -p1 < dbd-mysql-0.4.4_time.patch
mv Mysql.rb ${DIR_TARGET}/lib/ruby/gems/1.8/gems/dbd-mysql-0.4.4/lib/dbd/
rm dbd-mysql-0.4.4* 

    #8.4) Make sure your LD_LIBRARY_PATH contains BOTH ${DIR_TARGET}/mysql/lib and # TODO - is it needed ?
         #${DIR_TARGET}/mysql/lib/mysql. Otherwise certain libs can have a hard time finding
         #the .so they saw at compile time.

# needed by redmine
func_gem "mysql-2.9.1"
func_gem "activerecord-mysql-adapter-0.0.1"


#--------------------------------------------------------------------------
#F. Install Apache
#=================
#The Apache we build is statically linked for most modules. Optional
#modules that *might* be used can be built, but should be built as
#*shared* modules so they are only loaded if there is a LoadModule
#directive in the .conf file. This keeps Apache fast, since fewer
#extra modules have code registered for each event during the serving
#of pages. It also lowers re-start time.

#0) Make ${DIR_TARGET}/apache-<ver>
mkdir -p ${DIR_TARGET}/apache
mkdir -p ${DIR_TARGET}/apache/apr
func_get_package "httpd-2.2.26"
cd httpd-2.2.26

#1) Compile and INSTALL APR *FIRST*
#- this is the Apache Portable Runtime, which is needed by many
#modules and 3rd party libraries that integrate with Apache
#- you want this to be *exactly* matched for your Apache installation
#- you want to replace any existing version from previous Apaches
#- see more here, where we follow their compilation directions and
#put the APR stuff under apache/apr (this is where you will point
#the configure of 3rd party APR-using package to):
#http://httpd.apache.org/docs/2.2/install.html
#1.1)  Compile APR itself (./srclib/apr/ within the Apache tarball):
cd ./srclib/apr/
func_run "CFLAGS=' -O3 -fPIC ' ./configure --prefix=${DIR_TARGET}/apache/apr"
func_run "make -j ${CORES_NUMBER}"
func_run_test "make check"
func_run "make install"
cd ../..
#1.2)  Compile APR-Util (./srclib/apr-util/ within the Apache tarball):
cd ./srclib/apr-util/
func_run "CFLAGS=' -O3 -fPIC ' ./configure --prefix=${DIR_TARGET}/apache/apr --with-apr=${DIR_TARGET}/apache/apr --with-expat=/usr"
func_run "make -j ${CORES_NUMBER}"
func_run_test "make check"
func_run "make install"
cd ../..
#2) Compile Apache *NEXT*
#- Now we compile Apache itself, and point it to our APR and APR-Util compilations!
#- We will select certain modules to compile statically as part of
#  Apache (there are some default ones that get compiled statically,
#  although you can turn them off or make them shared)
#- We will turn on --enable-so to allow shared modules to be used
#- We will select certain modules we *might* use (but might not) to be compiled as shared modules
#- The list of modules you want to consider is here:
#  http://httpd.apache.org/docs/2.2/programs/configure.html#installationdirectories
#- You can read the advantages and disadvantages of shared vs static here:
#  http://httpd.apache.org/docs/2.2/dso.html#advantages. notice the +20% startup overhead and 
#  the +5% execution time warning for static modules
#- Generally, if you *definitely* use the module, static compile
#- Generally, if you *might* or *will test* use of the module, shared compile
#  and only LoadModule when you *start to use it*!! Otherwise, leave it off.
#- Generally, if you don't need it, *turn it OFF*; this will make Apache
#  faster and smaller
#- Generally, be careful turning off the core modules that are turned on by
#  default; but you can turn off ones you definitely won't use
#- go back up to the root of the apache source and do:
func_run "CFLAGS=' -O3 -fPIC ' ./configure --prefix=${DIR_TARGET}/apache 
--with-apr=${DIR_TARGET}/apache/apr 
--with-apr-util=${DIR_TARGET}/apache/apr 
--enable-so 
--disable-charset-lite 
--disable-include 
--enable-cache=shared 
--enable-deflate=static 
--enable-disk-cache=shared 
--enable-expires=static 
--enable-ext-filter=shared 
--enable-file-cache=shared 
--enable-headers=static 
--enable-mem-cache=shared 
--enable-mime-magic=static 
--enable-proxy=static 
--enable-proxy-ajp=static 
--enable-proxy-balancer=static 
--disable-proxy-connect 
--disable-proxy-ftp 
--enable-proxy-http=static 
--enable-rewrite=static 
--enable-ssl=static 
--enable-usertrack=shared 
--enable-vhost-alias=shared 
--with-ssl=${DIR_TARGET} 
--with-z=${DIR_TARGET}"
func_run "make -j ${CORES_NUMBER}"
func_run "make install"
cd ..
rm -rf httpd-2.2.26*

#3) Copy httpd.conf
func_get_package "httpd_conf/httpd.conf"
mv httpd.conf ${DIR_TARGET}/apache/conf/

#4) mod_ruby
func_get_package "mod_ruby-1.3.0"
cd mod_ruby-1.3.0
func_run "CXXFLAGS=' -O3 -fPIC ' CFLAGS=' -O3 -fPIC ' ./configure.rb
--prefix=${DIR_TARGET} 
--with-apxs=${DIR_TARGET}/apache/bin/apxs 
--with-apr-includes=${DIR_TARGET}/apache/apr/include/apr-1"
func_run "make"
func_run "make install"
cd ..
rm -rf mod_ruby-1.3.0*
      # TODO - remove this if works without that
      #4.1.1)  If configure.rb generates an error, that would be because they assume
              #the ruby CONFIG hash has a key for XLDFLAGS when it doesn't [in newer
              #versions]. Fix this by changing:
        #$XLDFLAGS = CONFIG["XLDFLAGS"]
            #to
        #$XLDFLAGS = CONFIG["XLDFLAGS"].to_s

#6. Create symbolic links in apache directory:- TODO - check if needed
# Yes, this is silly and should not be needed with sensible ruby install, lib dir, and apache environment. Legacy:
ln -s ../lib/ruby/site_ruby/1.8/ ${DIR_TARGET}/apache/ruby
# I can't currently explain why we should be doing this, if the environment is sensible:
mkdir -p ${DIR_TARGET}/apache/htdocs/webapps/java-bin


#G. Install Tomcat
#=================

# ---------------------- TODO - skip - I have installed binaries
  #First, get the SRC download of Tomcat 5.5.

  #Basically we follow the instructions here:
    #http://tomcat.apache.org/tomcat-5.5-doc/building.html # OR
    #http://tomcat.apache.org/tomcat-6.0-doc/building.html
  #Get the requirements (latest JDK, Ant, etc) then build Tomcat.

  #1)  You should have the latest JDK installed during a section above.

  #2)  Get ant
    #You should have this already, from a section above

  #3)  Use Ant to build Tomcat via Internet Installation
    #- Go into the "build/" subdir
    #- The build.xml script will download the latest stable srcs from a remote SVN
    #- You need to edit this file so it downloads things to the right dir (a tmp
      #download dir is the safest approach). Other edits may be necessary, unless
      #they have addressed certain install issues in your version.
    #- You will need a build.properties file along side the build.xml that came
      #with your tomcat source.
      #. There should be a build/build.properties.default file
      #. Copy it to build/build.properties and edit that file
      #. Editing the file is necessary for setting base path to
        #a dir under the tomcat source (the default is a bad place):

        ## ----- Proxy setup -----
        ## Uncomment if using a proxy server.
        ##proxy.host=proxy.domain
        ##proxy.port=8080
        ##proxy.use=on

        ## ----- Default Base Path for Dependent Packages -----
        ## Replace this path with the directory path where
        ## dependencies binaries should be downloaded.
        #base.path=<genbadmin home directory>/WORKSPACE/downloads/tomcat-{ver}/share/java
        ## EG:
        ##base.path=/opt/downloads/software/apache-tomcat-5.5.35-src/share/java

    #- Also in your new build properties, change the settings for compilation to try
      #turning on optimization and targetting java 1.5:

        ## ----- Compile Control Flags -----
        #compile.debug=on
        #compile.deprecation=off
        #compile.optimize=on
        #compile.source=1.5
        #compile.target=1.5

    #- Run 'ant download' to get and build certain dependencies (or 'ant checkout' for newer tomcats)
      #. OR ant checkout

    #- Run 'ant' to compile and install tomcat.
# ----------------------------------------------- end of skip 

func_get_package "apache-tomcat-5.5.36"
cd apache-tomcat-5.5.36
cp -r ./* ${DIR_TARGET}/apache/htdocs/
cd ..
rm -rf apache-tomcat-5.5.36*


    #- ${DIR_TARGET}/apache/tomcat will be further refered as $CATALINA_HOME - TODO - htdocs, not tomcat !!!
      #. you might want to export that right now, before continuing the install
    #- you can do the copying after building the native source parts and setting
      #up the Tomcat5.sh (just make sure to set your softlinks to the correct
      #installation location, not where you are building)
    #- if UPDATING existing Tomcat, DO NOT copy everything like above does; only
      #copy the bits you need to upgrade the existing Tomcat; here are the suggested bits:
#TODO - not everything is in the binary package
        #cd build/build
        #cp -Rf docs $CATALINA_HOME/
        #cp -Rf shared $CATALINA_HOME/
        #cp -Rf temp $CATALINA_HOME/
        #cp -Rf common $CATALINA_HOME/
        #cp -Rf classes $CATALINA_HOME/
        #cp -Rf lib $CATALINA_HOME/
        #cp -Rf bin $CATALINA_HOME/
        #cp -Rf server $CATALINA_HOME/
        #cp -Rf webapps/ROOT ${DIR_TARGET}/apache/htdocs/webapps/

#5) Build the Native Code for Tomcat (more speed, uses APR for some things)
func_get_package "httpd-2.2.26.t"
cp ${DIR_TARGET}/apache/htdocs/bin/tomcat-native.tar.gz .
tar xzf tomcat-native.tar.gz
cd tomcat-native-1.1.24-src/jni/native
func_run "./buildconf --with-apr=../../../httpd-2.2.26/srclib/apr"
func_run "CFLAGS=' -O3 -fPIC ' ./configure --with-apr=${DIR_TARGET}/apache/apr --with-ssl=${DIR_TARGET}"
func_run "make"
cd ../../../
mv tomcat-native-1.1.24-src ${DIR_TARGET}/apache/htdocs/bin/  # used in Tomcat5.sh start script !!!
rm -rf tomcat-native*  httpd-2.2.26*
    #- go to your $CATALINA_HOME/bin   - TODO - done, what now?
    #- untar the tomcat-native.1.1.6.tar.gz or similar
    #- go to $CATALINA_HOME/bin/tomcat-native-.1.1.6-src/jni/native
    #- build it using configure and such...don't forget to tell it where your APR is!
      #. first, you have to run buildconf and point it at the APR *SRC* dir:
          #./buildconf --with-apr=<httpd SRC directory>/srclib/apr
        #* eg:  ./buildconf --with-apr=/opt/downloads/software/httpd-2.4.2/srclib/apr
      #. then you run configure, using --with-apr to your COMPILED version; for example:
          #CFLAGS=" -O3 -fPIC " ./configure --with-apr=/opt/downloads/software/httpd-2.4.2/srclib/apr --with-ssl=${DIR_TARGET}
          #* Check the output and that it is finding your customer versions of ssl and jdk
          #* i.e. NOT system versions of those
      #. then 'make'
          #* You should not see any "-g" in the gcc compiles and you should see "-O3 -fPIC"
    #- you will use this (well the .libs dir it makes) in section 6 below
        ## ARJ NOTES: the regular approach works fine under CentOS 5.1+ which is RedHat enterprise. Manuel's notes deleted.
  
  
#6) Setup Tomcat to be Run as a Daemon
#- a standard part of setup, but obviously it is platform specific
#  See: http://tomcat.apache.org/tomcat-5.5-doc/setup.html
cp ${DIR_TARGET}/apache/htdocs/bin/commons-daemon-native.tar.gz .
tar xzf commons-daemon-native.tar.gz
cd commons-daemon-1.0.10-native-src/unix
func_run "./support/buildconf.sh"
chmod ug+x ./configure
func_run "CFLAGS=' -O3 -fPIC ' ./configure --with-java=${DIR_TARGET}/jdk --prefix=${DIR_TARGET}"
func_run "make clean"       # to remove any .o files that came in a bad package (you want to compile those!)
func_run "make"
cd ../../
mv commons-daemon-1.0.10-native-src ${DIR_TARGET}/apache/htdocs/bin/
rm commons-daemon-native.tar.gz
ln -s ./commons-daemon-1.0.10-native-src/unix/jsvc ${DIR_TARGET}/apache/htdocs/bin/jsvc
#- now 'jsvc' can be used to start Tomcat as a daemon. BUT WE DON'T USE THIS DIRECTLY.
      #- next, while in your $CATALINA_HOME/bin, normalize the Tomcat5.sh location with a softlink
        #(they keep moving it around, so we normalize):
            #ln -s ./commons-daemon-1.0.7-native-src/unix/samples/Tomcat5.sh
            #ln -s ./Tomcat5.sh ./Tomcat.sh
      #. as the instructions say, to integrate tomcat into /etc/init.d, we first
        #configure the file $CATALINA_HOME/bin/Tomcat5.sh
        #for our environment (user is 'nobody', JAVA_HOME, CATALINA_HOME etc, etc)
        #and it calls jsvc for us.
      #- make a backup of the Tomcat5.sh script:
          #cp $CATALINA_HOME/bin/commons-daemon-1.0.7-native-src/unix/samples/Tomcat5.sh $CATALINA_HOME/bin/commons-daemon-1.0.7-native-src/unix/samples/Tomcat5.sh.ORIG
      #- numerous changes to the tomcat5.sh/Tomcat5.sh script need to be made, as per 6.1 below

# func_get_package "apache-tomcat_conf/tomcat_init"   # taken from apache-tomcat-5.5.34/bin/commons-daemon-1.0.7-native-src/unix/samples/Tomcat5.sh and changed significantly
# mv tomcat_init ${DIR_TARGET}/etc/init.d/

    #- We've noticed some issues related to NamingBinding classes of Tomcat 5. These
      #throw exceptions in the logs that are related to manager.xml, admin.xml, and
      #others.
      #. one potential solution is to REMOVE naming-common.jar from the common/lib
        #dir of the tomcat installation; this file appears to have a conflicting
        #class with one that is supposedly in naming-resources.jar
      #. at this time, however, we're not 100% sure this is safe and not going to
        #break some operation of Tomcat we haven't yet exercised; so far, seems
        #necessary for Apache 2.

func_get_package "apache-tomcat_conf/workers.properties"
func_get_package "apache-tomcat_conf/server.xml"
mv workers.properties ${DIR_TARGET}/apache/htdocs/conf/
mv server.xml         ${DIR_TARGET}/apache/htdocs/conf/


  #7)  Configure Tomcat workers and server - TODO - adjust files
    #7.1) Edit the worker.properties files
      #- go to your $CATALINA_HOME/conf dir and notice there is a workers.properties
        #(if there is not, get one from existing server or from svn://histidine.brl.bcmd.bcm.edu/brl-repo/servers/tomcat/conf/)
        #. cp this file to workers.properties.ORIGINAL
        #. edit the workers.properties file like the URL above explains
          #> make sure workers.tomcat_home points to your $CATALINA_HOME
            #workers.tomcat_home=${DIR_TARGET}/apache/tomcat
          #> make sure workers.java_home points to your Java JDK top-level dir
            #workers.java_home=${DIR_TARGET}/jdk
          #> declare a simple workers list
            #workers.list=ajp13
        #. comment out the remaining definitions in the file

    #7.2) Edit the server.xml file - TODO - adjust files
      #- cp server.xml to server.xml.ORIG
      #- replace the server.xml file with the one from svn://histidine.brl.bcmd.bcm.edu/brl-repo/servers/tomcat/conf/

# apache/htdocs/work/Catalina/localhost directories
mkdir -p ${DIR_TARGET}/apache/htdocs/work/Catalina/localhost/admin
mkdir -p ${DIR_TARGET}/apache/htdocs/work/Catalina/localhost/graphics
mkdir -p ${DIR_TARGET}/apache/htdocs/work/Catalina/localhost/host-manager
mkdir -p ${DIR_TARGET}/apache/htdocs/work/Catalina/localhost/images
mkdir -p ${DIR_TARGET}/apache/htdocs/work/Catalina/localhost/java-bin
mkdir -p ${DIR_TARGET}/apache/htdocs/work/Catalina/localhost/javaScripts
mkdir -p ${DIR_TARGET}/apache/htdocs/work/Catalina/localhost/manager
mkdir -p ${DIR_TARGET}/apache/htdocs/work/Catalina/localhost/styles
mkdir -p ${DIR_TARGET}/apache/htdocs/work/Catalina/localhost/syntenyGIFS


func_get_package "context.xml.patch"
cp ${DIR_TARGET}/apache/htdocs/conf/context.xml .
patch -p1 < context.xml.patch
mv context.xml ${DIR_TARGET}/apache/htdocs/conf/
rm context.xml.patch


# TODO - testing ---------------------
    #7.6) Test the standalone tomcat installation:
      #- start up tomcat
      #- point your browser to localhost:8081
      #- check the JSP examples link

     #7.7) Test your apache+tomcat installation
      #- go to your apache/htdocs and make a softlink to
        #$CATALINA_HOME/webapps/jsp-examples
      #- start apache (and nginx)
      #- your should be able to go to http://your.domain.edu/jsp-examples/
        #. if everything is correct then you see the index.html page which
          #has links to various *working* JSP 2.0 examples
          #> this is served up by APACHE
        #. click a link (like 'Basic Arithmetic')
          #> this is a JSP page and is served up by TOMCAT

#--------------------------------------------------------------------------
# Install MongoDB
#===================

func_get_package "mongodb-linux-x86_64-2.6.7"
mkdir ${DIR_TARGET}/mongodb
mv mongodb-linux-x86_64-2.6.7/* ${DIR_TARGET}/mongodb/
rm -rf mongodb-linux-x86_64-2.6.7*
