#/bin/bash

. /users/andrewj/.cron.bashrc
# . /users/andrewj/.cron.Linux_i686_glibc-2.2.bashrc

RUBYPATH=/users/andrewj/brl/lib/ruby
RUBYOPT=" -rrubygems -rbrl/util/util -rbrl/util/textFileUtil "
EXE=/users/andrewj/brl/bin/serverMonitor.rb
PROP=/users/andrewj/brl/genboree/serverMonitor/monitorConfig.properties

ruby $RUBYOPT -I$RUBYPATH $EXE -p $PROP 2>/dev/null >/dev/null
