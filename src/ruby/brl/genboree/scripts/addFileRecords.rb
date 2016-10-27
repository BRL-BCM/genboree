#!/usr/bin/env ruby

# This script will replace the group and database names with their ids so that renaming databases and groups will not result in the loss of data

# Load dependencies
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/dbUtil'
require 'json'
require 'json/add/core'
require 'brl/util/util'
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
baseDir = "/usr/local/brl/data/genboree/files/grp"
# Iterate over each group and rename (move) all db names with refseqids and group names with group ids
files = []
grouprefseqHash.each_key { |groupId|
  groupRecs = dbu.selectGroupById(groupId)
  if(!groupRecs.nil? and !groupRecs.empty?)
    groupName = CGI.escape(groupRecs.first['groupName'])
    refseqHash = grouprefseqHash[groupId]
    refseqHash.each_key { |refseqId|
      refseqRecs = dbu.selectRefseqById(refseqId)
      if(!refseqRecs.nil? and !refseqRecs.empty?)
        refseqName = CGI.escape(refseqRecs.first['refseqName'])
        indexFile = "#{baseDir}/#{groupId}/db/#{refseqId}/databaseFiles.json"
        if(File.exists?(indexFile))
          $stderr.puts("Processing refseqId: #{refseqId}")
          dbu.setNewDataDb(refseqRecs.first['databaseName'])
          begin
            fileContents = JSON.parse(File.read(indexFile))
            $stderr.puts "Read and parsed index file"
          rescue => err
            $stderr.puts "JSON Parse error for: #{refseqId}"
            next
          end
          fileRecs = []
          fileContents.each { |file|
            description = file['description'] ? file['description'] : nil
            autoArchive = ( file['autoArchive'] == true ? 1 : 0 )
            hide = ( file['hide'] == true ? 1 : 0 )
            fileRecs << [file['fileName'], SHA1.hexdigest(file['fileName']), file['label'], description, autoArchive, hide, file['date'], Time.now(), gc.gbSuperuserId]
            $stderr.print(".") if(fileRecs.size > 0 and fileRecs.size % 1000 == 0)
          }
          $stderr.print("\nDone collecting recs...\n")
          begin
            dbu.insertFiles(fileRecs, fileRecs.size, false)
            $stderr.puts("Inserted all recs.")
          rescue => err
            $stderr.puts "insert failed: Error:\n#{err.message}\nBacktrace: #{err.backtrace.join("\n")}"
            next
          end
        end
      end
    }
  end
}
