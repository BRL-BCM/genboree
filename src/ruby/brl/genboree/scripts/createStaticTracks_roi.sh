RELEASE=$1
echo $RELEASE
source /usr/local/brl/home/genbadmin/.bashrc
DATADIR=/usr/local/brl/data/genboree/files/grp/Epigenomics%20Roadmap%20Repository/db/Release%20$RELEASE%20Repository
echo $DATADIR
createStaticTracks_roi.rb $RELEASE  >> $DATADIR/createStaticTracks_roi.out 2>> $DATADIR/createStaticTracks_roi.err
