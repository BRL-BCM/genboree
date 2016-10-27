#!/usr/bin/env ruby

# ##############################################################################
# REQUIRED CLASSES/MODULES
# ##############################################################################

require 'brl/db/dbrc'
require 'dbi'
require 'brl/genboree/dbUtil'
require 'brl/genboree/genboreeUtil'
require 'brl/util/timingUtil'

module BRL ; module Genboree

class FdataSearch
	# ############################################################################
	# CONSTANTS
	# ############################################################################
	# MAIN_GENB = 'genboree'
	CHR_SORT_RE = /^.*chr(.+)$/i

	# ############################################################################
	# ATTRIBUTES
	# ############################################################################
	attr_accessor :matches, :dbrcKey, :genbConfig, :groupMatches

	def initialize(refSeqId, dbrcFileName=nil)
	  @timer = BRL::Util::TimingUtil.new()
		@refSeqID = refSeqId
		@dbrcFileName = dbrcFileName
		@dataDBList = []
		@matches = {}
		# Load Genboree Config File (has the dbrcKey in it to use for this machine)
		@genbConfig = GenboreeConfig.new()
		@genbConfig.loadConfigFile()
		@dbu = BRL::Genboree::DBUtil.new(@genbConfig.dbrcKey, nil, @dbrcFileName)
		@groupMatches = true
	end

	def getScids()
		@scidList = @dbu.getScidForRefSeqID(@refSeqID)
		return @scidList
	end

	def getSearchConfigByScid(scid)
		@searchConfigList = @dbu.getSearchConfigByScid(scid)
		return @searchConfigList
	end

	def getDataDBList()
		uploadRows = @dbu.selectDBNamesByRefSeqID(@refSeqID)
		@dataDBList = []
		uploadRows.each { |uploadRow|
      @dataDBList << uploadRow['databaseName']
    }
		return @dataDBList
	end

	def searchAllDataDBs(keyword)
		@keyword = DBUtil.sqlEscape(keyword, true, false)
		@matches = {}
		getDataDBList()
		# For each data database
		@dataDBList.each { |dataDBName|
			# Connect to new data dir
			@dbu.setNewDataDb(dataDBName)
			# Get all the ftypes and create ftypeid->type:subtype hash
			ftypeArray = @dbu.selectAllFtypes()
			ftypeid2trackName = {}
			ftypeArray.each { |ftypeRec| ftypeid2trackName[ftypeRec['ftypeid']] = "#{ftypeRec['fmethod']}:#{ftypeRec['fsource']}" }
			# Get all annotations with name starting with keyword
			rawMatches = @dbu.selectFdataByGname(@keyword)
			# Search for chromosomes (frefs) that might match too
			frefMatches = @dbu.selectFrefsByName(@keyword)
			# Put frefMatches into rawMatches form
			rawMatches = addFrefsToRawMatches(frefMatches, rawMatches)
			# Convert to 1 annotation with start=min(starts) and stop=max(stops)
			# collapseRawMatches(rawMatches, rid2rname, ftypeid2trackName, gid2gclass)
			collapseRawMatches(rawMatches, ftypeid2trackName)
		}
		return @matches
	end
# GNAME, RID, FSTART, FSTOP, FTYPEID, FSCORE, FREF_NAME
  def addFrefsToRawMatches(frefMatches, rawMatches)
    return rawMatches if(frefMatches.nil? or frefMatches.empty?)
    frefMatches.each { |frefMatch|
      matchRecord = []
      matchRecord['gname'] = frefMatch['refname']
      matchRecord['rid'] = frefMatch['rid']
      matchRecord['fstart'] = 1
      matchRecord['fstop'] = frefMatch['rlength']
      matchRecord['ftypeid'] = 1
      matchRecord['fscore'] = 1.0
      matchRecord['refname'] = frefMatch['refname']
      rawMatches << matchRecord
    }
    return rawMatches
  end

	def collapseRawMatches(rawMatches, ftypeid2trackName)
		rawMatches.each { |rawMatch|
			rname = rawMatch['refname']
			ftypeName = rawMatch['ftypeid'] = ftypeid2trackName.key?(rawMatch['ftypeid']) ? ftypeid2trackName[rawMatch['ftypeid']] : ''
			gname = rawMatch['gname']
			unless(@matches.key?(gname)) # then it's not in there at all yet
				@matches[gname] = Hash.new { |hh,kk| hh[kk] = Hash.new { |gg,ll| gg[ll] = [] } }
				@matches[gname][ftypeName][rname] << rawMatch
			else # It's already in there
				# Is it in there under the same ftype?
				unless(@matches[gname].key?(ftypeName)) # then no, it's not
					@matches[gname][ftypeName] = Hash.new { |gg,ll| gg[ll] = [] }
					@matches[gname][ftypeName][rname] << rawMatch
				else # It's already in there for this ftype
					# Is it in there under the same entrypoint?
					if(!@matches[gname][ftypeName].key?(rname) or !@groupMatches)
						@matches[gname][ftypeName][rname] << rawMatch
					else # It's already in there and on the same chromosome and/or we need to
              # take min/max extents
              existStart = @matches[gname][ftypeName][rname][0]['fstart']
              existStop = @matches[gname][ftypeName][rname][0]['fstop']
              (existStart, existStop = existStop, existStart) if(existStart > existStop)
              currStart = rawMatch['fstart']
              currStop = rawMatch['fstop']
              (currStart, currStop = currStop, currStart) if(currStart > currStop)
              minCoord = ( currStart <= existStart ) ? currStart : existStart
              maxCoord = ( currStop >= existStop ) ? currStop : existStop
              @matches[gname][ftypeName][rname][0]['fstart'] = minCoord
              @matches[gname][ftypeName][rname][0]['fstop'] = maxCoord
					end
				end
			end
		}
		return @matches
	end

	# release resources
	def clear()
		@refSeqID = @dbrcFileName = @dataDBList = nil
		@scidList.clear unless(@scidList.nil?)
		@matches.clear unless(@matches.nil?)
		@dbu.clear unless(@dbu.nil?)
		return
	end
end # class FdataSearch

end ; end # module BRL ; module Genboree
