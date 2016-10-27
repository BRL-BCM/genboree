#!/usr/bin/env ruby
=begin
=end

# ##############################################################################
# $Copyright:$
# ##############################################################################
# ##############################################################################
# VERSION INFO
# ##############################################################################
# $Id$
# $Header: $
# $LastChangedDate$
# $LastChangedDate$
# $Change: $
# $HeadURL$
# $LastChangedRevision$
# $LastChangedBy$
# ##############################################################################

# ##############################################################################
# REQUIRED CLASSES/MODULES
# ##############################################################################
require 'brl/util/util'
require 'brl/util/propTable'
require 'brl/util/textFileUtil' # For TextReader/Writer classes
require 'uri'
require 'net/http'
require 'cgi'

module BRL ; module Net

OK, BAD_CHR, NEW_CHR, CANT = 0,1,2
COVERT_MSGS = [ 'OK', 'MOVED TO NEW CHR', "CAN'T CONVERT" ]
	
class UCSCDraftNameError < StandardError ; end
class UCSCQueryError < StandardError ; end
class UCSCParseError < StandardError ; end

class UCSCResponse
	attr_accessor :chrom, :value, :message
	
	def initialize(chrom, value, msg='')
		@chrom, @value, @message = chrom, value, msg
	end
end

class UCSCBadChrResponse < UCSCResponse ; end
class UCSCBadQueryResponse < UCSCResponse ; end
class UCSCNewChrResponse < UCSCResponse ; end
class UCSCOkResponse < UCSCResponse ; end
class UCSCCantConvertResponse < UCSCResponse ; end
class UCSCInternalServerError < UCSCResponse ; end
class UCSCRetryLimitExceeded < UCSCResponse ; end

class UCSCCoordConverter
	# Constants
	DOMAIN = 'genome.ucsc.edu'
	PORT = 80
	READ_TIMEOUT = 9000
	RETRY_UCSC_GET_LIMIT = 20
	RESOURCE_BASE = '/cgi-bin/hgCoordConv'
	CONVERSIONS =	{
	                'Mar. 2006'   => { 'May 2004' => '' },
									'May 2004'		=> { 'July 2003' => '', 'April 2003' => '', 'Mar. 2006' => '' },
									'July 2003'		=> { 'April 2003' => '', 'Nov. 2002' => '' },
									'April 2003'	=> { 'July 2003' => '', 'Nov. 2002' => '' },
									'Nov. 2002'		=> { 'July 2003' => '', 'April 2003' => '' }
								}
	ALIASES =	{
	            'hg18'  => 'Mar. 2006',
							'hg17'	=> 'May 2004',
							'hg15'	=> 'April 2003',
							'hg16'	=> 'July 2003',
							'hg13'	=> 'Nov. 2003'
						}
	
	CHR_RE = /^chr/i
	BAD_CHR_RE = /^<!-- HGERROR-START -->.*([^>]+can\'t find file for chromosome\s+(\S+)\.?).*<!-- HGERROR-END -->/m
	BAD_QUERY_RE = /^([^<]+)<!-- HGERROR -->/m
	CANT_CONVERT_RE = /Conversion Not Successful:.+?>\s*([^<]+)</
	OLD_COORD_RE = /Old Coordinates:[^:]+\s+([^:]+):(\d+)-/
	NEW_COORD_RE = /New Coordinates:[^:]+\s+([^:]+):(\d+)-/
	
	attr_accessor :srcName, :destName, :body
	attr_reader :http
	
	def initialize(srcName, destName)
	  @t1 = @t2 = Time.now
		srcName.strip! ; destName.strip!
		# Try to convert srcName and destName to aliases
		srcName = ALIASES[srcName.downcase] if(ALIASES.key?(srcName.downcase))
		destName = ALIASES[destName.downcase] if(ALIASES.key?(destName.downcase))
		# Sanity check the names
		if(srcName == destName)
			raise UCSCDraftNameError, "\n\nERROR: the srcName and the destName arguments refer to the same draft!\n"
		end
		unless(CONVERSIONS.key?(srcName))
			raise UCSCDraftNameError, "\n\nERROR: the srcName argument '#{srcName}' is not one of the known draft names:\n" + UCSCCoordConverter.getValidSrcs().join("\n") + "\n\n"
		end
		unless(CONVERSIONS[srcName].key?(destName))
			raise UCSCDraftNameError, "\n\nERROR: the destName argument '#{destName}' is not one of the drafts '#{srcName}' can be converted to:\n" + UCSCCoordConverter.getValidDests(srcName).join("\n") + "\n\n"
		end
		# Names are ok
		@srcName, @destName = srcName, destName
		@origGenome = CGI.escape(@srcName)
		@newGenome = CGI.escape(@destName)
		# Open the Http 1.1 connection (should have keep-alive)
		@http = nil
		initHttp()
	end
	
	def initHttp()
		unless(@http.nil?)
			begin
				@http.finish
			rescue
			ensure
				@http = nil
			end
		end
		@http = ::Net::HTTP.new(DOMAIN, PORT)
		@http.read_timeout = READ_TIMEOUT
		@http.start
	end
	
	def convertCoord(chr, coord)
		# http://genome.ucsc.edu/cgi-bin/hgCoordConv?origGenome=July+2003&position=CHR22%3A17045228-17054909&newGenome=Nov.+2002&calledSelf=on
		chr = "chr" + chr.to_s unless(chr =~ CHR_RE)
		queryStr =	"#{RESOURCE_BASE}?origGenome=#{@origGenome}&position=" +
									CGI.escape(chr + ':' + coord.to_s + '-' + coord.to_s) +
									"&newGenome=#{@newGenome}&Submit=submit&calledSelf=on"
		# $stderr.puts "\nQUERY: #{queryStr}\n\n"
		resp = nil
		retryCount = 0
		loop {
		  if(retryCount < RETRY_UCSC_GET_LIMIT)
  			retryCount += 1
  			begin
  				resp = @http.get(queryStr)
  				if(resp.code =~ /500/)
  				  sleep(60)
  				  initHttp()
  				  redo
  				end
  			rescue Exception => err
  				sleep(1)
  				initHttp()
  				redo
  			else
  				break
  			end
  		else
  		  raise UCSCRetryLimitExceeded, "\n\nERROR: tried #{RETRY_UCSC_GET_LIMIT} times to query UCSC but all failed. The http response was:\n\tCode: '#{resp.code}'\n\tMsg:  '#{resp.message}'.\n\n"
  		end
		}
		unless(resp.is_a?(::Net::HTTPSuccess))
			raise UCSCQueryError, "\n\nERROR: bad http response from domain '#{DOMAIN}:#{PORT}' in retrieving the resource '#{queryStr}'. The http response was:\n\tCode: '#{resp.code}'\n\tMsg:  '#{resp.message}'.\n\n"
		end
		return self.parseResponse(resp)
	end
	
	def parseResponse(resp)		
		@body = resp.body()
		if(@body =~ BAD_CHR_RE)	# then unknown chr
			return UCSCBadChrResponse.new($2, $2, $1)
		elsif(@body =~ CANT_CONVERT_RE)
			return UCSCCantConvertResponse.new(nil, nil, $1)
		elsif(@body =~ BAD_QUERY_RE)
			raise UCSCQueryError, "\n\nERROR: this tool made a bad query to the UCSC web service. UCSC's Error Message:\n\t'#{$1}'\n\n"
		else	# Appears to be converted
			if(@body =~ OLD_COORD_RE)
				oldChr = $1
				oldCoord = $2
			else
				raise UCSCParseError, "\n\nERROR: supposedly successful reply from UCSC couldn't be parsed. Format changed? Full text below.\n\n'#{body}'\n\n"
			end
			if(@body =~ NEW_COORD_RE)
				newChr = $1
				newCoord = $2
			else
				raise UCSCParseError, "\n\nERROR: supposedly successful reply from UCSC couldn't be parsed. Format changed? Full text below.\n\n'#{body}'\n\n"
			end
			# Check if new chr or not...	
			if(oldChr == newChr) # then same chr
				return UCSCOkResponse.new(newChr, newCoord)
			else	# new chr!
				return UCSCNewChrResponse.new(newChr, newCoord)
			end
		end				
	end
	
	def finish()
		begin
			@http.finish()
		rescue
		end
		return
	end
	
	def clear()
		self.finish()
		@http, @srcName, @destName, @origGenome, @newGenome = nil
		return
	end
	
	def UCSCCoordConverter.getValidSrcs()
		validSrcs = CONVERSIONS.keys
		ALIASES.each { |key, val| validSrcs << key if(CONVERSIONS.key?(val))	}
		return validSrcs
	end
	
	def UCSCCoordConverter.getValidDests(srcName)
		return [] unless(CONVERSIONS.key?(srcName))
		validDests = CONVERSIONS[srcName].keys
		ALIASES.each { |key, val| validDests << key if(CONVERSIONS[srcName].key?(val)) }
		return validDests
	end
	 
end	# class UCSCCoordConverter

end ; end 	# module BRL ; module Net
