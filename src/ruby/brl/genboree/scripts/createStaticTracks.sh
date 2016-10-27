RELEASE=$1
source /usr/local/brl/home/genbadmin/.bashrc
DATADIR=/usr/local/brl/data/genboree/files/grp/Epigenomics%20Roadmap%20Repository/db/Release%20$RELEASE%20Repository/
createStaticTracks_All.rb  >> $DATADIR/createStaticTracks_All.out 2>> $DATADIR/createStaticTracks_All.err

