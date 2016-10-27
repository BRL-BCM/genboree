#!/bin/bash

set -e  # stop on first error
set -u  # stop when tries to use uninitialized variable

DIR_SCRIPTS="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"   # directory with scripts
source ${DIR_SCRIPTS}/conf_build.sh


set -v  # print commands


#if false; then  # debug

#jsbeautify.py
func_get_package "jsbeautify.py"
mv jsbeautify.py ${DIR_TARGET}/bin/

#1) Get brl ruby library code tree
cp -R ${DIR_SRC}/ruby/* ${DIR_TARGET}/lib/ruby/site_ruby/1.8/


#G. Final configuration
#======================
#1) Set up symbolic links to Java source code locations and populate them
ln -s ../lib/ruby/site_ruby/1.8/ ${DIR_TARGET}/apache/ruby
ln -s ./htdocs/webapps/java-bin  ${DIR_TARGET}/apache/java-bin

#4.3)  Make some key links in htdocs/webapps and clean up default Tomcat stuff
#- Remove default Tomcat content:
for xx in balancer jsp-examples servlet-examples tomcat-docs webdav ROOT
do
	rm -rf ${DIR_TARGET}/apache/htdocs/webapps/${xx}
done

#Add key links for html page stuff: 
for xx in javaScripts styles images syntenyGIFS graphics 
do 
	ln -s ../${xx} ${DIR_TARGET}/apache/htdocs/webapps/${xx}
done
ln -s java-bin ${DIR_TARGET}/apache/htdocs/webapps/ROOT


  #3) Try to access the page http://<server>/genboree/formParams.rhtml?foo=bar - TODO - test
      #to check that ruby is configured properly for apache.

#4.1)  Now deploy these dirs from SVN
ln -s ${DIR_SRC}/java java_src

#java) grab mysql driver
func_get_package 'mysql-connector-java-5.1.36'
mv  mysql-connector-java-5.1.36/mysql-connector-java-5.1.36-bin.jar  java_src/lib/
ln -s  mysql-connector-java-5.1.36-bin.jar  java_src/lib/mysql-connector-java.jar  
rm  -rf  mysql-connector-java-5.1.36*


#8) In ~/JavaSrc, build java code by running ant:
cd java_src
mkdir -p classes dist images
func_run "ant"
# this is needed to run tomcat - TODO - remove other old libraries taken from svn !!! (some of them shadow original libraries from Tomcat)
# rm -rf ./lib/naming-common.jar
# move content to the output directories
#mv ./htdocs/*   ${DIR_TARGET}/apache/htdocs/
cp -R ${DIR_SRC}/htdocs/*  ${DIR_TARGET}/apache/htdocs/
mv ./lib/*      ${DIR_TARGET}/apache/htdocs/common/lib/
#mv ./java-bin/* ${DIR_TARGET}/apache/htdocs/webapps/java-bin/

cd ..
rm -rf java_src


#5) Deploy the brl ruby code library and mod_ruby:
      #- In SVN dir for //brl-depot/brl/src/ruby: TODO - done at the beginning of build_gems
          #cp -r brl ${DIR_TARGET}/lib/ruby/site_ruby/1.8/
#- Create symbolic links to brl executables:
          ## First, go to SVN dir for //brl-repo/genboree/docs/Genboree-Install/conf-files
          ## Check out files, then do:
func_get_package "ruby_conf/brl.ruby.list"  # from svn://histidine.brl.bcmd.bcm.edu/brl-repo/genboree/docs/Genboree-Install/conf-files
func_get_package "ruby_conf/gem.list"       # from svn://histidine.brl.bcmd.bcm.edu/brl-repo/genboree/docs/Genboree-Install/conf-files
for f in `cat ./brl.ruby.list`   # do I need that ?
do
	find ${DIR_TARGET}/lib/ruby/site_ruby/1.8/brl/ -name ${f} -exec ln -s {} ${DIR_TARGET}/bin \;
done
# TODO - is it needed ? (links exist)
for f in `cat ./gem.list`
do
	find ${DIR_TARGET}/lib/ruby/ -name ${f} -exec ln -s {} ${DIR_TARGET}/bin \;
done
chmod +x ${DIR_TARGET}/bin/*.rb
rm brl.ruby.list gem.list


#6) Configure apache for MySQL access
mkdir -p ${DIR_TARGET}/apache/ruby/conf/apache
func_get_package "httpd_conf/magic.genboree"              # from svn://histidine.brl.bcmd.bcm.edu/brl-repo/brl/3rdPartyTools/file/
func_get_package "httpd_conf/colorCode.txt"               # from svn://histidine.brl.bcmd.bcm.edu/brl-repo/servers/conf/
mv magic.genboree              ${DIR_TARGET}/apache/
mv colorCode.txt               ${DIR_TARGET}/apache/
	# TODO
	#- Ensure that .dbrc file contains a row with the key (first column) of "genboree"
	#which indicates the MAIN genboree data driver information.
	#- Configure both .dbrc and genboree.config.properties to reflect
	#your machine name and genboree user password.
	#- Configure genboree.config.properties to reflect the default
	#user db host (not the web server machine for multiple machine setup).

#7) Setup genbadmin-runnable apache and tomcat start & stop scripts
ln -s ${DIR_SRC}/c/suidWrappers suidWrappers
mkdir -p ${DIR_TARGET}/bin/suid
cd suidWrappers
for xx in *.c 
do 
	yy=`echo ${xx} | sed -e 's/\.c$//'`
	gcc -o ${yy} ${xx}
	mv ${yy} ${DIR_TARGET}/bin/suid/
done
cd ..
rm -rf suidWrappers
            
      # TODO - is it needed
      #- As genbadmin, go to ${DIR_TARGET}/apache/bin and do:
          #for xx in ${DIR_TARGET}/bin/suid/tomcat*; do echo $xx ; ln -s $xx ; done
          ## This provides backward-compatibility for a bad file tree (apache/bin for our
          ## stuff == bad)


  #10) Place the default.xml needed for the *OLD* VGP into CATALINA_HOME (hopefully this - TODO - what is that ?
     #step will go away with the new VGP soon)
      #- cp brl-repo/genboree/JavaSrc/src/org/genboree/svg/default.xml $CATALINA_HOME
      #- make sure nobody can read the file ; it doesn't need to write the file


#11) Compile the image generator for gbrowser, myTest.exe, and copy it under
      #${DIR_TARGET}/apache/htdocs/webapps/java-bin/WEB-INF:
ln -s ${DIR_SRC}/c/optimizedGenomeViewer optimizedGenomeViewer
cd optimizedGenomeViewer
func_get_package "optimizedGenomeViewer"
patch -p1 < optimizedGenomeViewer_includes.patch   # fix #include directives with hardcoded paths
patch -p1 < optimizedGenomeViewer_libs.patch       # remove linkings to some libraries (Makefile)
func_run "make"
mv myTest.exe ${DIR_TARGET}/apache/htdocs/webapps/java-bin/WEB-INF/
cd ..
rm -rf optimizedGenomeViewer*


#12) web.xml to right place:
func_get_package "apache-tomcat_conf/web.xml"      # from svn://histidine.brl.bcmd.bcm.edu/brl-repo/servers/tomcat/WEB-INF/web.xml
mv web.xml ${DIR_TARGET}/apache/htdocs/webapps/java-bin/WEB-INF/


#13) Setup more file & directories permissions 
mkdir -p ${DIR_TARGET}/apache/htdocs/graphics 
mkdir -p ${DIR_TARGET}/apache/htdocs/cache

        #cp ../brl-depot/genboree/.../Genboree-Install/conf-files/examples* ${DIR_MAIN}/data/genboree/deploymentTool/ - TODO ???


#15) Retrieve the toolPlugins' nameSelector resources from  - TODO - already exists in lib/ruby/site_ruby/...
#svn export svn://histidine.brl.bcmd.bcm.edu/brl-repo/brl/src/ruby/brl/genboree/toolPlugins/resources
#mv resources /usr/local/brl/data/genboree/toolPlugins/


  #16) Install and fix the location specific files, maintained in a  - TODO - customization
      #separate SVN repository, one for genboree installation. Some
      #pages need to be modified by hand, to replace hard-code email
      #addresses, logos, copyright info, etc. with the proper ones.

      #In principle, once set up, the following files can be copied directly.
      #We recommend using diff and understanding the changes. If the
      #changes include only logo/http info, then copy the files over the
      #ones obtained from the Genboree SVN repository. Otherwise, patch the
      #current files with your company's information, and add them to the
      #location-specific repository.

      #header.incl
      #footer.incl
      #brlNews.html
      #genboreeContentNews.html
      #projectPageLinks.incl

      #For the following files, inspect the current version and the
      #location-specific version, and apply changes sensibly

      #gbrowser.jsp
        #-- replace the BCM logo with something appropriate
      #genboreeSearchWrapper.rhtml
        #-- replace the BCM logo with something appropriate
        #-- we used code that extracts the technical contact email
           #from the configuration file

  #17) Retrieve the hg 18 template sequence files from /usr/local/brl/data/genboree/ridSequences - TODO
      #on another genboree installation.
        #cd /usr/local/brl/data/genboree/ridSequences
        #rsync -avr --files-from=<config files>/libraryFeatures.tables.list  \
               #user@host:/usr/local/brl/data/genboree/ridSequences .
        #find . -type d -exec chmod 2775 {} \;
        #find . -type f -exec chmod 644 {} \;

  #18) Within BRL/BCM you will need the deploymentTool.rb set up and working  - TODO - propably not needed
    #- deployTool.rb should already be available in ${DIR_TARGET}/bin by from an above step
    #- make sure to copy /usr/local/brl/data/genboree/deploymentTool tree from somewhere ;
      #in particular you need .properties and .list files and the per-project sub-dirs with
      #their definitions
    #- then run deploy tool:
        #deployTool.rb -p /usr/local/brl/data/genboree/deploymentTool/deployTool.properties
    #- then fix dir permissions so .cache files can be made:
        ## go to ~/JavaSrc/java-bin
        #find . -type d -exec chmod g+ws {} \;

#19) Compile jimKent code and deploy key apps
func_get_package "kent-v296_branch.1"   # from http://genome-source.cse.ucsc.edu/gitweb/ , see http://genome.ucsc.edu/admin/git.html
mkdir -p ~/bin/x86_64             # they require this...
cd kent/src/lib/
func_run "MACHTYPE=x86_64 HG_WARN=' -Wall -Wformat -Wimplicit -Wreturn-type ' COPT=' -O3 -fPIC ' make"
cd ../jkOwnLib/
func_run "MACHTYPE=x86_64 HG_WARN=' -Wall -Wformat -Wimplicit -Wreturn-type ' COPT=' -O3 -fPIC ' make"
cd ../utils/wigToBigWig/
func_run "MACHTYPE=x86_64 HG_WARN=' -Wall -Wformat -Wimplicit -Wreturn-type ' COPT=' -O3 -fPIC ' make"
cd ../bedToBigBed/
func_run "MACHTYPE=x86_64 HG_WARN=' -Wall -Wformat -Wimplicit -Wreturn-type ' COPT=' -O3 -fPIC ' make"
cd ../bedGraphToBigWig/
func_run "MACHTYPE=x86_64 HG_WARN=' -Wall -Wformat -Wimplicit -Wreturn-type ' COPT=' -O3 -fPIC ' make"
cd ../wigToBedGraph/
func_run "MACHTYPE=x86_64 HG_WARN=' -Wall -Wformat -Wimplicit -Wreturn-type ' COPT=' -O3 -fPIC ' make"
cd ../../../..
mv ~/bin/x86_64/wigToBigWig      ${DIR_TARGET}/bin/
mv ~/bin/x86_64/bedToBigBed      ${DIR_TARGET}/bin/
mv ~/bin/x86_64/bedGraphToBigWig ${DIR_TARGET}/bin/
mv ~/bin/x86_64/wigToBedGraph    ${DIR_TARGET}/bin/
rm -rf kent-v296_branch.1* kent
    #-To Build wigToBigWig yourself, follow the instructions at:
       #http://genomewiki.ucsc.edu/index.php/CVS_kent_source_tree_control
    #. but use a different cvsroot dir than /scratch/cvsroot
    #. stop after "cvs co -kk -rbeta kent"
    #. NOTE: To get it build (even in the face of some warnings they have but which error-out
      #due to their gcc flags) make sure to issue the 'make' commands with the variable values
      #set as shown below. This will OVERRIDE the defaults in .../inc/common.mk which can result
      #in failed builds of some tools (eg they have warnings but with -Werror, it turns into a compile error;
      #eg they have -O -g but you want just -O3 -fPIC)
    #. This process should work:
        #CVSROOT=`pwd`/cvsroot
        #export CVSROOT
        #cvs -d $CVSROOT init
        #CVSROOT=:pserver:anonymous@genome-test.cse.ucsc.edu:/cbse
        #export CVSROOT
        #cvs login # <- use 'genome' for password
        #cd cvsroot/
        #cvs co -kk -rbeta kent # repeat until this completes w/o error
        #export MACHTYPE=x86_64
        #mkdir -p ~/bin/$MACHTYPE  # they require this...
        #cd kent/src/jkOwnLib/
        #make clean
        #HG_WARN=" -Wall -Wformat -Wimplicit -Wreturn-type " COPT=" -O3 -fPIC " make
        #cd ../lib/
        #make clean
        #HG_WARN=" -Wall -Wformat -Wimplicit -Wreturn-type " COPT=" -O3 -fPIC " make
        #cd ../utils/wigToBigWig/
        #make clean
        #HG_WARN=" -Wall -Wformat -Wimplicit -Wreturn-type " COPT=" -O3 -fPIC " make
        #~/bin/x86_64/wigToBigWig # should give usage
        #cp ~/bin/x86_64/wigToBigWig  ${DIR_TARGET}/bin/
        #cd ../bedToBigBed/
        #make clean
        #HG_WARN=" -Wall -Wformat -Wimplicit -Wreturn-type " COPT=" -O3 -fPIC " make
        #~/bin/x86_64/bedToBigBed # should give usage
        #cp  ~/bin/x86_64/bedToBigBed ${DIR_TARGET}/bin/
        #cd ../bedGraphToBigWig/
        #make clean
        #HG_WARN=" -Wall -Wformat -Wimplicit -Wreturn-type " COPT=" -O3 -fPIC " make
        #~/bin/x86_64/bedGraphToBigWig # should give usage
        #cp ~/bin/x86_64/bedGraphToBigWig ${DIR_TARGET}/bin/
        #cd ../wigToBedGraph/
        #make clean
        #HG_WARN=" -Wall -Wformat -Wimplicit -Wreturn-type " COPT=" -O3 -fPIC " make
        #~/bin/x86_64/wigToBedGraph # should give usage
        #cp ~/bin/x86_64/wigToBedGraph ${DIR_TARGET}/bin/

  #20) Move or link jsbeautify to ${DIR_TARGET}/bin/  - TODO - done in build_gems
    #- svn://histidine.brl.bcmd.bcm.edu/brl-repo/brl/3rdPartyTools/jsbeautify/jsbeautify.py


#H. Test the genboree installation  - TODO - tests
#=================================

 #1) Browse under the group libraryFeatures the hg18 database
   #1.1) view PNG
   #1.2) can get popups when track is clicked and when annotation is clicked
   #1.3) can click "Base" and get base pairs on PNG
   #1.4) "GetDNA" lets you download sequence, with and without
      #repeat-masked feature

 #2) Do a search in hg18 under libraryFeatures for "pros"
   #2.1) should see several matches for this term
   #2.2) no error screen (missed something in install)

 #3) Can Create Database using the hg18 template to create a brand new
 #database
   #3.1) can Upload Data (some small hg18-valid LFF file) into this database
   #3.2) can Upload Data for some small .psl (blat) file into this database

 #4) Tools - Plugins - Name Selection
    #. can get annos -like- "PROS*" from the Gene:RefSeq track into a new
      #track
    #. verify the Tools - Plugin Results can show you your job results
    #. verify resulting new track has been uploaded into the database

 #5) Browse the database from #3 and click on the track name on the PNG
    #. view tabular view of data
    #. save the tabular view configuration
    #. view annos as a table (view 200 per page)
    #. go back, choose a different view, then go back again and try to
      #use the view you -saved- ; should be listed and should work if
      #needed dirs exist

#I. Using The Accounts Feature - TODO - unsupported feature - used in localhost processing?
#=============================
  #Genboree supports a limited concept of 'accounts' which can be used to restrict
  #resources and perhaps form the foundation of 'account billing'. Currently, if
  #turned on, the accounts feature has code to enforce a maximum number of users
  #and a maximum number of databases with an 'account'. Users will be required
  #to provide the appropriate 'account code' when creating a database or when
  #registering as a user.

  #To set up an account, you will need to do some SQL. There is no GUI because
  #you're one of the only 4 people (+/- 10) in the whole world who might have to
  #do this.

  #Create the account by inserting a record into the 'accounts' table of the
  #main genboree database. You will need a name for the account, an account
  #code to give to the account holders, a primary contact name, and a primary
  #contact email address. For example:

    #insert into accounts values (null, 'testAccnt', '-ddVT0',
      #'George Washington', 'gw@bigwhitehouse.gov') ;
    #select LAST_INSERT_ID() ;

  #For generating the code, you can make one up or use a snippet like this irb:

    #alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-'
    #myKey = "" ; 6.times {|ii| myKey << alphabet[rand(alphabet.length)] } ; myKey

  #You will give the code minimally to the primary account holder. He will give it
  #to any people he wants to be able to register with Genboree as users, and who
  #may need to create user databases.

  #Next you need to set some values for the 'maxNumUsers' and 'maxNumDatabases'
  #attributes for your new account. Note that LAST_INSERT_ID() returned
  #above is the account_id.

  #Add the values you plan on setting to the accountValues, IF they ARE NOT there
  #already. For example:

    #insert into accountValues values (null, '2', SHA('2')) ;

  #Now, set the value for maxNumUsers and maxNumDatabases by putting an appropriate
  #entry in the accounts2attributeValues table, which maps accounts to attributes
  #and the value for that attribue. For example, if the
  #accountAttribute_id of maxNumUsers and maxNumDatabases are 2 and 4, respectively
  #and the accountValue_id of '2' is 7, then to set both limits to 2 you'd do:

    #insert into accounts2attributeValues values (<account_id>, 2, 7) ;
    #insert into accounts2attributeValues values (<account_id>, 4, 7) ;

  #This is pretty self-explanatory from the field names.

  #You can add other accountAttributes if you want and set appropriate values for
  #them in the same way.

  #If you want to change the maxNumUsers or maxNumDatabases values, basically
  #repeat this process: make sure your value is in the accountValues table first
  #and note its id. Then update the accounts2attributeValues table to point to
  #that value for the attribute instead (for some account):

    #update accounts2attributeValues set accountValue_id = <newValue_id> where
      #account_id = <account_id> and accountAttribute_id=<acountAttribute_id>

  #Fill in the <> fields with the appropriate numbers.

# missing permissions
chmod a+x -R ${DIR_TARGET}/lib/ruby/site_ruby/1.8/brl/genboree/tools/scripts/MBW/*.rb
chmod a+x ${DIR_TARGET}/lib/ruby/site_ruby/1.8/brl/genboree/utilityApps/referenceGenomes.rb

# missing links
ln -s ${DIR_DATA}/genboree/projects ${DIR_TARGET}/apache/htdocs/projects
mkdir -p ${DIR_TARGET}/lib/ruby/site_ruby/1.8/brl/microbiome/workbench
ln -s ../../genboree/tools/scripts/MBW/brlMatrix.rb         ${DIR_TARGET}/lib/ruby/site_ruby/1.8/brl/microbiome/workbench/
ln -s ../../genboree/tools/scripts/MBW/RandomForestUtils.rb ${DIR_TARGET}/lib/ruby/site_ruby/1.8/brl/microbiome/workbench/
ln -s ../../genboree/tools/scripts/MBW/sample_class.rb      ${DIR_TARGET}/lib/ruby/site_ruby/1.8/brl/microbiome/workbench/
ln -s ../lib/ruby/site_ruby/1.8/brl/genboree/tools/scripts/MBW/sff_extract       ${DIR_TARGET}/bin/
ln -s ../lib/ruby/site_ruby/1.8/brl/genboree/utilityApps/referenceGenomes.rb     ${DIR_TARGET}/bin/
ln -s ../lib/ruby/site_ruby/1.8/brl/genboree/utilityApps/createDbForGenboreKB.rb ${DIR_TARGET}/bin/
ln -s ../lib/ruby/site_ruby/1.8/brl/genboree/utilityApps/createCollection.rb     ${DIR_TARGET}/bin/

# copy api
cp -r ${DIR_SRC}/api ${DIR_TARGET}/

# copy init scripts and configuration files from etc (including hidden files)
cp -r ${DIR_SRC}/etc/. ${DIR_TARGET}/etc/

# home directory
cp -r ${DIR_SRC}/home ${DIR_TARGET}/

# copy scripts with runtime environment
cp ${DIR_SCRIPTS}/conf_global.sh      ${DIR_TARGET}/etc/init.d/
cp ${DIR_SCRIPTS}/conf_runtime.sh     ${DIR_TARGET}/etc/init.d/
cp ${DIR_SCRIPTS}/conf_global.sh      ${DIR_TARGET}/home/
cp ${DIR_SCRIPTS}/conf_runtime.sh     ${DIR_TARGET}/home/

# copy directory with migrations
cp -r ${DIR_SRC}/migrations           ${DIR_TARGET}/home/

# conf tools from toolInfoConfUpdate_BigMod
cp -R ${DIR_SRC}/conf ${DIR_TARGET}/conf

# set version number
sed -i "s/__GENBOREE_VERSION__/${GENB_VERSION}/g" ${DIR_TARGET}/apache/htdocs/webapps/java-bin/mygenboree.jsp
sed -i "s/__GENBOREE_VERSION__/${GENB_VERSION}/g" ${DIR_TARGET}/apache/htdocs/webapps/java-bin/login.jsp
sed -i "s/__GENBOREE_VERSION__/${GENB_VERSION}/g" ${DIR_TARGET}/apache/htdocs/webapps/java-bin/include/footer.incl
sed -i "s/__GENBOREE_VERSION__/${GENB_VERSION}/g" ${DIR_TARGET}/apache/htdocs/genboree/footer.rhtml
sed -i "s/__GENBOREE_VERSION__/${GENB_VERSION}/g" ${DIR_TARGET}/apache/htdocs/resources/hostedSites/headerFooter.config.json
echo "${GENB_VERSION}" > ${DIR_TARGET}/version
echo "${GENB_VERSION}" > ${DIR_DATA}/version

# #########################
# Load brl/genboree/hdhv to create ruby inlines.
# #########################
mkdir -p  ${INLINEDIR}
chmod 755 ${INLINEDIR}
cd ${INLINEDIR}
func_run "ruby -r 'rubygems' -r 'brl/genboree/hdhv' -e ''"
cd -


# ================== Links
ln -s ${DIR_TARGET}/lib/ruby/site_ruby/1.8/brl/genboree/prequeue/scripts/jobsSubmitter.rb  ${DIR_TARGET}/bin
ln -s ${DIR_TARGET}/lib/ruby/site_ruby/1.8/brl/genboree/prequeue/scripts/statusUpdater.rb  ${DIR_TARGET}/bin
ln -s ${DIR_TARGET}/lib/ruby/site_ruby/1.8/brl/genboree/prequeue/scripts/commandsRunner.rb ${DIR_TARGET}/bin
ln -s ${DIR_TARGET}/lib/ruby/site_ruby/1.8/brl/genboree/helpers/bed2lff.rb         ${DIR_TARGET}/bin
ln -s ${DIR_TARGET}/lib/ruby/site_ruby/1.8/brl/genboree/helpers/bedgraphToWig.rb   ${DIR_TARGET}/bin
ln -s ${DIR_TARGET}/lib/ruby/site_ruby/1.8/brl/genboree/helpers/expander.rb        ${DIR_TARGET}/bin
ln -s ${DIR_TARGET}/lib/ruby/site_ruby/1.8/brl/genboree/helpers/fileApiTransfer.rb ${DIR_TARGET}/bin
ln -s ${DIR_TARGET}/lib/ruby/site_ruby/1.8/brl/genboree/helpers/gff32lff.rb        ${DIR_TARGET}/bin
ln -s ${DIR_TARGET}/lib/ruby/site_ruby/1.8/brl/genboree/scripts/createZoomLevelsAndUploadLFF.rb ${DIR_TARGET}/bin
ln -s ${DIR_TARGET}/lib/ruby/site_ruby/1.8/brl/genboree/scripts/createZoomLevelsForLFF.rb       ${DIR_TARGET}/bin
ln -s ${DIR_TARGET}/lib/ruby/site_ruby/1.8/brl/genboree/scripts/findMinMaxPos_loci.rb           ${DIR_TARGET}/bin
ln -s ${DIR_TARGET}/lib/ruby/site_ruby/1.8/brl/genboree/scripts/genboreeToolAutoTester.rb       ${DIR_TARGET}/bin
# general command for creating links to all scripts from genboree/tools/scripts
find  ${DIR_TARGET}/lib/ruby/site_ruby/1.8/brl/genboree/tools/scripts -name '*.rb' -exec ln -s {} ${DIR_TARGET}/bin \;


