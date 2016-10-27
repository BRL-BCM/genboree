#/bin/bash

. /users/andrewj/.cron.bashrc
#LINUX 2.2: . /users/andrewj/.cron.Linux_i686_glibc-2.2.bashrc

RUBYPATH=/users/andrewj/brl/lib/ruby
EXE=/users/andrewj/brl/bin/lffAutoUploader.rb
#EXE=/users/andrewj/work/brl/src/ruby/brl/genboree/lffAutoUploader.rb
PROP=/home/po4a/brl/genboree/alanineInBox/globalLFFUpload.properties
OUTFILE=/home/po4a/brl/genboree/alanineInBox/globalLog/autoLFFUpload.out
ERRFILE=/home/po4a/brl/genboree/alanineInBox/globalLog/autoLFFUpload.err

date >>  $OUTFILE
date >> $ERRFILE
echo "------------------------" >> $OUTFILE
echo "------------------------" >> $ERRFILE
ruby -I$RUBYPATH $EXE -p $PROP >> $OUTFILE 2>> $ERRFILE
