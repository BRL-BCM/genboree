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
grouprefseqHash.each_key { |groupId|
  groupRecs = dbu.selectGroupById(groupId)
  if(!groupRecs.nil? and !groupRecs.empty?)
    groupName = CGI.escape(groupRecs.first['groupName'])
    refseqHash = grouprefseqHash[groupId]
    refseqHash.each_key { |refseqId|
      refseqRecs = dbu.selectRefseqById(refseqId)
      if(!refseqRecs.nil? and !refseqRecs.empty?)
        refseqName = CGI.escape(refseqRecs.first['refseqName'])
        dir = "#{baseDir}/#{groupId}/db/#{refseqId}"
        if(File.exists?(dir))
          $stderr.puts("Processing refseqId: #{refseqId}")
          dbu.setNewDataDb(refseqRecs.first['databaseName'])
          Dir.chdir(dir)
          files = `find ./ -type f`
          fileRecs = []
          if(!files.empty?)
            fileList = files.split(/\n/)
            fileList.each { |file|
              file.strip!
              file.gsub!(/^\.\//, '')
              next if(file == 'databaseFiles.json')
              fileRecs << [file, SHA1.hexdigest(file), file, nil, 0, 0, Time.now(), Time.now(), gc.gbSuperuserId]
            }
            begin
              dbu.insertFiles(fileRecs, fileRecs.size, false) if(!fileRecs.empty?)
            rescue => err
              $stderr.puts "insert failed: Error:\n#{err.message}\nBacktrace: #{err.backtrace.join("\n")}"
              next
            end
          end
        end
      end
    }
  end
}
