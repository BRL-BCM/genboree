#!/usr/bin/env ruby

# This script adds zoom level info to all existing tracks in all existing databases
# Notes: use the latest version of dbUtil
# Additionally, this script must be run from a directory that is not world or group
# readable or writable because of the rubyinline code.

require "rubygems"
require 'brl/genboree/dbUtil'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/scripts/addZoomLevels'

gc = BRL::Genboree::GenboreeConfig.load
dbu = BRL::Genboree::DBUtil.new("#{gc.dbrcKey}", nil, nil)
dbs = dbu.selectAllDbNamesFromRefseq
#dbs = ['genboree_r_e5b1f99c9a3d81f81a4776544872fbd6']
#dbs = ["genboree_r_ffcd153762307558f2b841826055aa96"]
dbs.each { |db|
  begin
  dbName = db['databaseName']
  #dbName = db
  dbu.setNewDataDb(dbName)
  dbu.connectToDataDb() # caching enabled, but will force each *user data* dbh closed as we are done with them below
  $stderr.puts "connected to db: #{dbName}"
  tracks = dbu.selectAllFtypes
  tracks.each { |track|
    begin
      ftypeId = track['ftypeid'].to_i
      recordType = dbu.getTrackRecordType(ftypeId)
      if(!recordType.empty? and (recordType[0][0] == 'floatScore' or recordType[0][0] == 'doubleScore')) #Only add zoom level info if track is hdhv
        $stderr.puts "processing track: #{track['fmethod']}:#{track['fsource']}"
        $stderr.puts "NOTE: record type is double score!" if(recordType[0][0] == 'doubleScore')
        zoom = BRL::Genboree::AddZoomLevels.new("#{dbName}", "#{track['fmethod']}:#{track['fsource']}", dbu)
        zoom.addZoomLevelInfo
        $stderr.puts "track: #{track['fmethod']}:#{track['fsource']} done"
      elsif(!recordType.empty? and recordType[0][0] == 'int8Score')
        $stderr.puts "track: #{track['fmethod']}:#{track['fsource']} has recordType: int8Score"
      elsif(!recordType.empty? and (recordType[0][0] == 'floatScore' or recordType[0][0] == 'doubleScore') and !zoomLevelsPresent.empty?)
        $stderr.puts "#{track['fmethod']}:#{track['fsource']} already has zoom levels. "
      end
    rescue Exception => errTrack
      $stderr.puts "error with track: #{track['fmethod']}:#{track['fsource']} in db: #{dbName}. ERROR: #{errTrack}"
      next
    end
  }
  rescue Exception => err
    # skip to the next database
    $stderr.puts "error with db: #{dbName}. ERROR: #{err}.\n#{err.backtrace.join("\n")}"
    next
  end
  # because cached, set the "forceClosed" arg to true when closing:
  closedOk = dbu.closeDbh(dbu.dataDbh, true)
  $stderr.puts "db: #{dbName} done (closed ok? #{closedOk})"
  # $stderr.puts "DEBUG: dbu.dataDbh = #{dbu.dataDbh.inspect} ; cached key? #{dbu.dbh2driver.key?(dbu.dataDbh)}"
}
$stderr.puts "all done"
