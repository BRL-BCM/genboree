#!/usr/bin/env ruby

# Author: Sameer Paithankar
# A script to delete all the contents of a group including db records and stuff under /usr/local/brl/data/genboree/files/grp/{grp}
# The script is intended to be launched as a daemon by the rest resource 'group.rb' (for delete) so that group contents are deleted in the background and the user immediately gets a response
# The script is not multi-host compliant. It takes groupId as an argument and will try to nuke contents of that group on the local machine

# Load dependencies
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/dbUtil'

# Get groupid from the command line
groupId = ARGV[0]
genbConf = BRL::Genboree::GenboreeConfig.load
dbu = BRL::Genboree::DBUtil.new(genbConf.dbrcKey, nil, nil)

# Get all the dbs under this group and nuke them
grouprefseqRecs = dbu.selectGroupRefSeqByGroupId(groupId)
if(!grouprefseqRecs.nil? and !grouprefseqRecs.empty?)
  grouprefseqRecs.each { |grouprefseqRec|
    refSeqId = grouprefseqRec['refSeqId']
    refSeqRecs = dbu.selectRefseqById(refSeqId)
    dbName = refSeqRecs.first['databaseName']
    dbu.setNewDataDb(dbName)
    dbu.dropDatabase(dbName)
    dbu.deleteGroupRefSeq(groupId, refSeqId)
    dbu.deleteRefseqRecordByRefSeqId(refSeqId)
    dbu.deleteDatabase2HostRecByDatabaseName(dbName)
    `rm -rf #{genbConf.ridSequencesDir.chomp("/")}/#{refSeqId}`
  }
end
`rm -rf #{genbConf.gbAnnoDataFilesDir.chomp("/")}/grp/#{groupId}`
`rm -rf #{genbConf.gbDataFileRoot.chomp("/")}/grp/#{groupId}`
