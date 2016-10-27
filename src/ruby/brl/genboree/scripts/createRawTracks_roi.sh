GROUP=$1
DB=$2
FORMAT=$3
source /usr/local/brl/home/genbadmin/.bashrc
#DATADIR=/usr/local/brl/data/genboree/files/grp/Epigenomics%20Roadmap%20Repository/db/Release%20$RELEASE%20Repository
#echo $DATADIR
createRawTracks_roi.rb "$GROUP" "$DB" $FORMAT skipLock >> /usr/local/brl/data/genboree/files/grp/ROI%20Repository/db/ROI%20Repository%20-%20hg19/createRawTracks_roi.out 2>> /usr/local/brl/data/genboree/files/grp/ROI%20Repository/db/ROI%20Repository%20-%20hg19/createRawTracks_roi.err
