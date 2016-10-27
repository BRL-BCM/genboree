#!/usr/bin/env ruby

# Author: Sameer Paithankar
# A script to delete all the data for a track (except the ftypeid) including blockLevel/fdata2 recs and/or bigwig/bigbed files
# The script is intended to be launched as a daemon by the rest resource 'tracks.rb' (for delete) so that the track data is deleted in the background and the user immediately gets a response
# The script is not multi-host compliant. It takes a comma separated list of ftypeids alongwith the refseqId and groupid of the database and group where the tracks reside.

# Load dependencies
require 'cgi'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/dbUtil'
require 'brl/genboree/abstract/resources/track'
require 'brl/genboree/abstract/resources/unlockedGroupResource'
require 'brl/genboree/abstract/resources/ucscBigFile'

# Get args from the command line
groupId = ARGV[0]
refSeqId = ARGV[1]
ftypeids = ARGV[2]
ftypeidList = ftypeids.split('-')
#$stderr.puts(ftypeidList.inspect)
#raise ''
genbConf = BRL::Genboree::GenboreeConfig.load
dbu = BRL::Genboree::DBUtil.new(genbConf.dbrcKey, nil, nil)
refSeqRecs = dbu.selectRefseqById(refSeqId)
dbName = refSeqRecs.first['databaseName']
dbu.setNewDataDb(dbName)
# delete any binary files and records in blockLevelDataInfo
ftypeidList.each {|fTypeId|
  BRL::Genboree::Abstract::Resources::Track.deleteHdhvData(dbu, fTypeId)
  # Get rid or any gbKeys
  BRL::Genboree::Abstract::Resources::UnlockedGroupResource.lockTrackById(dbu, groupId, refSeqId, fTypeId)
  # Need to remove annotationDataFiles
  `rm -f #{genbConf.gbAnnoDataFilesDir.chomp('/')}/grp/#{groupId}/db/#{refSeqId}/trk/#{fTypeId}/trackAnnos.bw`
  `rm -f #{genbConf.gbAnnoDataFilesDir.chomp('/')}/grp/#{groupId}/db/#{refSeqId}/trk/#{fTypeId}/trackAnnos.bb`
  # Delete all ftype related data
  dbu.deleteByFieldAndValue(:userDB, 'featuresort', 'ftypeid', fTypeId, 'ERROR: BRL::Rest::Resouces::Track.delete()')
  dbu.deleteByFieldAndValue(:userDB, 'featuretostyle', 'ftypeid', fTypeId, 'ERROR: BRL::Rest::Resouces::Track.delete()')
  dbu.deleteByFieldAndValue(:userDB, 'featuretolink', 'ftypeid', fTypeId, 'ERROR: BRL::Rest::Resouces::Track.delete()')
  dbu.deleteByFieldAndValue(:userDB, 'featuretocolor', 'ftypeid', fTypeId, 'ERROR: BRL::Rest::Resouces::Track.delete()')
  dbu.deleteByFieldAndValue(:userDB, 'featureurl', 'ftypeid', fTypeId, 'ERROR: BRL::Rest::Resouces::Track.delete()')
  dbu.deleteByFieldAndValue(:userDB, 'featuredisplay', 'ftypeid', fTypeId, 'ERROR: BRL::Rest::Resouces::Track.delete()')
  dbu.deleteByFieldAndValue(:userDB, 'ftype2attributes', 'ftype_id', fTypeId, 'ERROR: BRL::Rest::Resouces::Track.delete()')
  dbu.deleteByFieldAndValue(:userDB, 'ftype2attributeName', 'ftypeid', fTypeId, 'ERROR: BRL::Rest::Resouces::Track.delete()')
  dbu.deleteByFieldAndValue(:userDB, 'ftypeAttrDisplays', 'ftype_id', fTypeId, 'ERROR: BRL::Rest::Resouces::Track.delete()')
  dbu.deleteByFieldAndValue(:userDB, 'ftypeCount', 'ftypeId', fTypeId, 'ERROR: BRL::Rest::Resouces::Track.delete()')
  dbu.deleteByFieldAndValue(:userDB, 'ftype2gclass', 'ftypeid', fTypeId, 'ERROR: BRL::Rest::Resouces::Track.delete()')
  dbu.deleteByFieldAndValue(:userDB, 'blockLevelDataInfo', 'ftypeid', fTypeId, 'ERROR: BRL::Rest::Resouces::Track.delete()')
  dbu.deleteByFieldAndValue(:userDB, 'ftypeAccess', 'ftypeid', fTypeId, 'ERROR: BRL::Rest::Resouces::Track.delete()')
  dbu.deleteByFieldAndValue(:userDB, 'fdata2', 'ftypeid', fTypeId, 'ERROR: BRL::Rest::Resouces::Track.delete()')
  dbu.deleteByFieldAndValue(:userDB, 'ftype', 'ftypeid', fTypeId, 'ERROR: BRL::Rest::Resouces::Track.delete()')
  dbu.deleteByFieldAndValue(:userDB, 'zoomLevels', 'ftypeid', fTypeId, 'ERROR: BRL::Rest::Resouces::Track.delete()')  
}
