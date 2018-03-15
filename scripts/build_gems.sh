#!/bin/bash

set -e  # stop on first error
set -u  # stop when tries to use uninitialized variable

DIR_SCRIPTS="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"   # directory with scripts
source ${DIR_SCRIPTS}/conf_build.sh

set -v  # print commands

#if false; then  # debug

mkdir -p ${DIR_TARGET}/lib/ruby/site_ruby/1.8/

#1) Get brl ruby library code tree  # moved to build_final

#2) rubygems
func_get_package "rubygems-2.1.11"
cd rubygems-2.1.11
func_run "RUBYOPT= ruby setup.rb --no-document"  # we have to clear RUBYOPT for this command
cd ..
rm -rf rubygems-2.1.11*

# need by console
func_gem "rb-readline-0.5.1"

#3) facets
func_gem "facets-1.8.54"

#4) daemons
func_gem "daemons-1.1.9"

#5) abstract
func_gem "abstract-1.0.0"

#6) amatch
func_gem "tins-0.13.2"
func_gem "amatch-0.2.11"
  #TODO - do I need that ?
  #. Note: Florian has moved this over to a gem but the gem doesn't runn
    #ruby install.rb in the current version. Thus "require 'amatch'" in irb
    #with throw an error (and break Genboree search!)
    #- to fix this, you can go to this gem's dir and do "ruby install.rb" manually:
        #cd ${DIR_TARGET}/lib/ruby/gems/1.8/gems/amatch-0.2.4
        #ruby install.rb

#7)  erubis
func_gem "erubis-2.7.0"

#14) json
func_get_package "json-1.8.1"
func_run "gem install --local json-1.8.1.gem"
#14.5) You are probably MISSING the site_ruby/1.8/json/add/rails.rb file!!
#- Disappeared from recent gitHub vesion
#- Old version still works [for our uses at least]
#- YOU MUST HAVE THIS FILE OR brl/activeSupport/activeSupport.rb's fixes to rails will not work!
#- Grab a copy from an older version of json. We saved a snapshot in SVN:
#. svn://histidine.brl.bcmd.bcm.edu/brl-repo/brl/3rdPartyTools/json-1.4.6.site_ruby-1.8.rbDirOnly/add/rails.rb
mkdir -p               ${DIR_TARGET}/lib/ruby/gems/1.8/gems/json-1.8.1/lib/json/add/
mv json-1.8.1_rails.rb ${DIR_TARGET}/lib/ruby/gems/1.8/gems/json-1.8.1/lib/json/add/rails.rb
rm json-1.8.1*
# TODO - correct that, pretty_generate doesn't work
  #DO NOT install the json gem, at least for now. We need to be able to reload json/ext.rb forcibly
  #to work around a conflict with ActiveSupport and we can't do the forced reload through the gem
  #mechanism, only through regular ruby require/load mechanisms.

  #NOTE: The installer seems to be broken. It will deploy the .so C extensions but fail to
  #copy the .rb files and other stuff that needs to go into site_ruby/1.8/json
  #(Follow directions below to install correctly)

  #14.1) Download source .zip from github (not rubyforge! old!) and unpack
    #- https://github.com/flori/json
  #14.2) Remove old version if present:
    #- in your site_ruby/1.8 or site_ruby/1.9 area:
      #. remove the json.rb
      #. remove the json/ dir
      #. remove the x86_64-linux/json/ dir
  #14.2) rake install
    #- this should install the .so libs to x86_64-linux/json/ext/
      #. check date is correct and present!
  #14.3) ruby install.rb
    #- this should create json/ dir in your site_ruby/1.8/ area
      #. it MAY copy over json.rb to site_ruby/1.8/ as well
    #- but it will be empty! bug!
  #14.4) Manually copy over .rb bits
    #- cp -R lib/json* {your site_ruby/1.8 or similar!}

    #- Deploy to site_ruby/1.8/json/add/rails.rb
  #14.6) If you do the following in ripl or irb, you should see your new version and NOT
    #the old version. Also, the quick check using ENV should not fail.
    #PPP: run require 'rubygems' first !!!!
      #require 'json/ext' # try to load C extensions specifically (not normally needed--we just do require "json"-- but we want to see if not found!)
      #require 'json/add/core'   #=> true (little check)
      #require 'json/add/rails'  #=> true (little check)
      #JSON::VERSION #=> your new version
      #puts JSON.pretty_generate(ENV.to_hash) #=> nicely formatted JSON
      #oo = JSON.parse( JSON.pretty_generate(ENV.to_hash) ) # oo should be Ruby Hash


#8)  rails
func_gem "rake-10.1.1"
func_gem "mime-types-1.25.1"

func_gem "bundler-1.6.3"
func_gem "builder-3.0.0"
func_gem "i18n-0.6.11"
func_gem "multi_json-1.10.1"
func_gem "activesupport-3.2.15"
func_gem "activemodel-3.2.15"
func_gem "rack-1.4.5"
func_gem "rack-cache-1.2"
func_gem "rack-test-0.6.2"
func_gem "hike-1.2.3"
func_gem "tilt-1.4.1"
func_gem "sprockets-2.2.2"
func_gem "journey-1.0.4"
func_gem "actionpack-3.2.15"
func_gem "polyglot-0.3.5"
func_gem "treetop-1.4.15"
func_gem "mail-2.5.4"
func_gem "actionmailer-3.2.15"
func_gem "arel-3.0.3"
func_gem "tzinfo-0.3.40"
func_gem "activerecord-3.2.15"
func_gem "activeresource-3.2.15"
func_gem "rack-ssl-1.3.4"
rm /usr/local/brl/local/bin/rdoc
rm /usr/local/brl/local/bin/ri
func_gem "rdoc-3.12.2"
func_gem "thor-0.19.1"
func_gem "railties-3.2.15"
func_gem "rails-3.2.15"


#9) aspectr
func_gem "aspectr-0.3.7"


#10) testunitxml
func_gem "testunitxml-0.1.5"


#13) RubyInline
func_gem "ZenTest-4.9.5"
func_gem "RubyInline-3.12.2"


#13) Mechanize
func_gem "net-http-digest_auth-1.4"
func_gem "net-http-persistent-2.9.4"
func_gem "nokogiri-1.5.11"
func_gem "ntlm-http-0.1.1"
func_gem "webrobots-0.1.1"
func_gem "unf_ext-0.0.6"
func_gem "unf-0.1.3"
func_gem "domain_name-0.5.16"
func_gem "mechanize-2.5.1"


#15) wirble
func_get_package "wirble-0.1.3"
func_run "gem install --local wirble-0.1.3.gem"
rm wirble-0.1.3*


#16)  narray
func_get_package "narray-0.6.0.8"
func_get_package "quanty-1.2.0"
func_run "gem install --local quanty-1.2.0.gem"
func_run "gem install --local narray-0.6.0.8.gem"
rm narray-0.6.0.8* quanty-1.2.0*


#17) rsruby
func_get_package "rsruby-0.5.1.1"
func_run "gem install --local rsruby-0.5.1.1.gem -- --with-R-dir=${DIR_TARGET}/lib/R"
rm rsruby-0.5.1.1*


#18) bz2
func_get_package "bz2-0.2.2"
func_run "gem install --local bz2-0.2.2.gem"
rm bz2-0.2.2*


#20) rest-open-uri
func_gem "rest-open-uri-1.0.0"


#21) bioruby
func_gem "bio-1.4.3.0001"


#23)  intervals
#Gem version of install is broken. Is missing a key -fPIC in one of gcc lines. (PPP: it's true)
#19.1)  Get & unpack the .tar.gz from rubyforge
#18.2)  Go to ext subdir of the package and compile the extensions:
func_get_package "intervals-0.5.83"
cd intervals-0.5.83/ext/
tar xzf crlibm.tar.gz
cd crlibm
CFLAGS=' -O3 -fPIC ' ./configure --prefix=${DIR_TARGET}
make
make install
func_run "make check"
cd ..
func_run "ruby extconf.rb"
func_run "make"
func_run "make install"
cd ../lib/
cp *rb ${DIR_TARGET}/lib/ruby/site_ruby/1.8/x86_64-linux/
cd ../..
rm -rf intervals-0.5.83*


#24) rb-gsl
func_gem "rb-gsl-1.16.0"


#25) mutexm.rb
func_get_package "mutexm-1.0.1"
cp mutexm-1.0.1/lib/mutexm.rb ${DIR_TARGET}/lib/ruby/site_ruby/1.8/
rm -rf mutexm-1.0.1*


#26) eruby
#Note: although Genboree will use the much faster (ruby code; this is slower C
#code) in erubis, there are a couple classes & methods we want to use from here.
#Note: this requires Apache. Can skip if not installing full apache.
func_get_package "eruby-1.0.5"
cd eruby-1.0.5
patch -p1 < ../eruby-1.0.5.patch
func_run "./configure.rb --mandir=${DIR_TARGET}/man"
func_run "make"
func_run "make install"
cd ..
rm -rf eruby-1.0.5*


#27) RMagick
func_get_package "rmagick-2.13.2"
func_run "gem install --local rmagick-2.13.2.gem"
rm rmagick-2.13.2*


#28) rein
func_get_package "rein-0.1.0"     # from BRL SVN repository !!!!! svn://proline.brl.bcm.tmc.edu/brl-repo/brl/3rdPartyTools/rein-0.1.0/
cd rein-0.1.0
func_run "ruby setup.rb config"
func_run "ruby setup.rb install"
cd ..
rm -rf rein-0.1.0*


#29) wadl library
func_gem "WADL-20070217"   # from BRL SVN repository !!!!! svn://proline.brl.bcm.tmc.edu/brl-repo/brl/3rdPartyTools/wadl


#XX - mine) Newick
func_gem "fpdf-1.53"
func_gem "newick-ruby-1.0.3"


#XX - mine) roo
func_gem "ruby-ole-1.2.11.7"
func_gem "spreadsheet-0.6.9"
func_gem "rubyzip-0.9.9"
func_gem "roo-1.10.3"


#XX ) mongo-1.10.2
func_gem "bson-1.10.2"
func_gem "bson_ext-1.10.2"
func_gem "mongo-1.10.2"


#XX ) clbustos-rtf-0.4.2
func_gem "clbustos-rtf-0.4.2"


func_gem "text-table-1.2.3"
func_gem "prawn-core-0.8.4"
func_gem "prawn-layout-0.8.4"
func_gem "prawn-security-0.8.4"
func_gem "prawn-0.8.4"
func_gem "prawn-svg-0.9.1.11"

#XX ) reportbuilder-1.4.2
func_gem "reportbuilder-1.4.2"

func_gem "minimization-0.2.1"
func_gem "fastercsv-1.5.5"
func_gem "dirty-memoize-0.0.4"
func_gem "extendmatrix-0.3.1"
func_gem "distribution-0.7.0"
func_gem "statsample-bivariate-extension-1.1.0"
func_gem "rserve-client-0.2.5"
func_gem "rubyvis-0.6.0"

#XX ) statsample-1.3.0
func_gem "statsample-1.3.0"


#XX )
func_gem "fast_xs-0.8.0"
func_gem "simple_xlsx_writer-0.5.3"


#31) Do "gem install" for each of these:
#hpricot 
func_gem "hpricot-0.8.6"
#libxml-ruby
func_get_package "libxml-ruby-2.7.0"
func_run "gem install --local libxml-ruby-2.7.0.gem -- --with-xml2-config=${DIR_TARGET}/bin/xml2-config"
rm libxml-ruby-2.7.0*
#libxslt-ruby
func_get_package "libxslt-ruby-1.1.0"
func_run "gem install --local libxslt-ruby-1.1.0.gem -- 
--with-xml2-lib=${DIR_TARGET}/lib
--with-xml2-include=${DIR_TARGET}/include/libxml2
--with-xslt-lib=${DIR_TARGET}/lib
--with-xslt-include=${DIR_TARGET}/include/libxslt
--with-exslt-lib=${DIR_TARGET}/lib
--with-exslt-include=${DIR_TARGET}/include/libexslt"
rm libxslt-ruby-1.1.0*
#ruby-prof
func_gem "ruby-prof-0.13.1"
#syntax
func_gem "syntax-1.2.0"
#open4
func_gem "open4-1.3.2"
#popen4
func_gem "Platform-0.4.0"
func_gem "popen4-0.1.2"

# for Redmine
func_gem "eventmachine-1.0.3"
func_gem "thin-1.6.2"
func_gem "ruby-openid-2.3.0"
func_gem "rack-openid-1.4.2"
func_gem "jquery-rails-2.0.3"
func_gem "coderay-1.1.0"
func_gem "net-ldap-0.3.1"

# for website
func_gem "RedCloth-4.2.9"


# 2014-07-08.addMeasurementsToKbFixExtensionsLocation
func_gem "ruby-units-1.4.5"

# 2014-10-23.bioOntology
func_gem "parallel-1.3.3"

# 2015-03-12.jsonStreamUpload
# This version was edited by Aaron (to drop the ruby>=1.9.2 dependency)
func_get_package "json-stream-0.2.1_brl"
cd json-stream-0.2.1_brl
func_run "gem build ./json-stream.gemspec"
func_run "gem install --no-document --local json-stream-0.2.1.gem"
cd ..
rm -rf json-stream-0.2.1_brl*

# 2015-06-22.asyncDownloadAndPreloadingDocs
func_gem 'addressable-2.3.8'
func_gem 'cookiejar-0.3.2'
func_gem 'em-socksify-0.3.0'
func_gem 'http_parser.rb-0.6.0'
func_gem 'em-http-request-1.1.2'

# missing stuff
func_gem "diffy-3.0.7"

# 2016-06-16.revHistoryForOutcomes - genboree_ac
func_gem 'uri_template-0.7.0'
func_gem 'safe_yaml-1.0.4'
func_gem 'crack-0.4.3'
func_gem 'differ-0.1.2'
func_gem 'escape_utils-0.3.2'
func_gem 'rails-dbi-0.1.2'

# 2017-10-05.memoize
func_gem 'memoist-0.15.0'

