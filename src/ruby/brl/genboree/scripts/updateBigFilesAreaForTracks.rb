#!/usr/bin/env ruby

# This script will replace the group and database names with their ids so that renaming databases and groups will not result in the loss of data

# Load dependencies
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/dbUtil'

# First get all the records from 'grouprefseq' and make a hash with group ids being keys and values being another hash with refseqids being keys
gc = BRL::Genboree::GenboreeConfig.load
dbu = BRL::Genboree::DBUtil.new(gc.dbrcKey, nil, nil)
grouprefseqRecs = dbu.getAllgrouprefseqRecs()
grouprefseqHash = Hash.new{ |hh,kk|
  hh[kk] = {}
}
grouprefseqRecs.each{ |rec|
  grouprefseqHash[rec['groupId']][rec['refSeqId']] = nil
}
# Iterate over each group and rename (move) all db names with refseqids and group names with group ids
baseDir = "/usr/local/brl/data/genboree/annotationDataFiles/grp"
allGroups = dbu.getAllGroups()
allGroups.each { |groupRec|
  groupId = groupRec['groupId']
  groupName = CGI.escape(groupRec['groupName'])
  if(grouprefseqHash.key?(groupId))
    refseqHash = grouprefseqHash[groupId]
    refseqHash.each_key { |refseqId|
      refseqRecs = dbu.selectRefseqById(refseqId)
      if(!refseqRecs.nil? and !refseqRecs.empty?)
        dirToCheck = "#{baseDir}/#{groupId}/db/#{refseqId}/trk"
        dbu.setNewDataDb(refseqRecs.first['databaseName'])
        if(File.exists?(dirToCheck))
          Dir.entries(dirToCheck).each { |trk|
            next if(trk == "." or trk == "..")
            dirToMv = "#{dirToCheck}/#{trk}"
            trkName = CGI.unescape(trk)
            trkRecs = dbu.selectFtypeByTrackName(trkName)
            if(!trkRecs.nil? and !trkRecs.empty?)
              ftypeid = trkRecs.first['ftypeid']
              dirToCreate = "#{dirToCheck}/#{ftypeid}"
              $stderr.puts("Moving #{dirToMv} #{dirToCreate}")
              `mv #{dirToMv} #{dirToCreate}`
            else
              $stderr.puts("Warning: trkName: #{trkName} does not have any record in ftype table.")
            end
          }
        end
      else
        $stderr.puts("Warning: refseqId: #{refseqId.inspect} does not have any records in refseq table. (But found in grouprefseq table)")
      end
    }
  else
    $stderr.puts("Warning: Group: #{groupName} does not have any dbs (No entry in grouprefseq table)")
  end
}
