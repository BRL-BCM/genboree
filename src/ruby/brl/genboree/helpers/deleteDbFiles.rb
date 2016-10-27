#!/usr/bin/env ruby

# Author: Sameer Paithankar

# Load dependencies
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/dbUtil'

groupId = ARGV[0]
refSeqId = ARGV[1]
genbConf = BRL::Genboree::GenboreeConfig.load
dbu = BRL::Genboree::DBUtil.new(genbConf.dbrcKey, nil, nil)
# Remove the ridSequences(bin files), annotationDataFiles(bgWig/bigBed) and Files directories for the database
`rm -rf #{genbConf.gbDataFileRoot.chomp("/")}/grp/#{groupId}/db/#{refSeqId}`
`rm -rf #{genbConf.ridSequencesDir.chomp("/")}/#{refSeqId}`
`rm -rf #{genbConf.gbAnnoDataFilesDir.chomp("/")}/grp/#{groupId}/db/#{refSeqId}`
