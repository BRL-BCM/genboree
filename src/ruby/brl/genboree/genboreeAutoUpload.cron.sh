#/bin/bash

. /users/andrewj/.cron.bashrc
#LINUX 2.2: . /users/andrewj/.cron.Linux_i686_glibc-2.2.bashrc

RUBYPATH=/users/andrewj/brl/lib/ruby
EXE=/users/andrewj/brl/bin/lffAutoUploader.rb
PROP=/users/andrewj/brl/genboree/autoUploadInBox/globalLFFUpload.properties
OUTFILE=/users/andrewj/brl/genboree/autoUploadInBox/globalLog/autoLFFUpload.out
ERRFILE=/users/andrewj/brl/genboree/autoUploadInBox/globalLog/autoLFFUpload.err

date >>  $OUTFILE
date >> $ERRFILE
echo "------------------------" >> $OUTFILE
echo "------------------------" >> $ERRFILE
ruby -I$RUBYPATH $EXE -p $PROP >> $OUTFILE 2>> $ERRFILE
