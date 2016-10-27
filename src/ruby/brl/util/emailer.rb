#!/usr/bin/env ruby
=begin
=end

# ##############################################################################
# REQUIRED CLASSES/MODULES
# ##############################################################################
require 'getoptlong'						# for GetoptLong class (command line option parse)
require 'cgi'
require 'net/smtp'
require 'timeout'
require 'resolv'
require 'brl/util/util'					# for to_hash extension of GetoptLong class
require 'brl/util/propTable'
require 'brl/util/textFileUtil' # For TextReader/Writer classes
require 'brl/genboree/genboreeUtil'   # BRL::Genboree::GenboreeConfig
$VERBOSE = (ENV['RUBY_VERBOSE'] == 'true' ? true : (ENV['RUBY_VERBOSE'] == 'false' ? false : nil))

module BRL ; module Util

class EmailFormatError < StandardError
end

class Emailer
	genbConfig = BRL::Genboree::GenboreeConfig.load()
	SMTP_SERVER = genbConfig.gbSmtpHost
	SMTP_PORT   = genbConfig.gbSmtpPort

	attr_accessor :mailFrom, :replyToHeader, :toList, :dateHeader, :fromHeader, :toHeader, :subjectHeader, :body
	attr_reader :sendError, :sendWarning

  # ------------------------------------------------------------------
  # CLASS METHODS
  # ------------------------------------------------------------------
  def self.validateEmailPattern(email)
    return (email.strip =~ /^[^@ \t\n]+@(?:[^\. \t\n]+\.)*[^\. \t\n]+\.[^\. \t\n]+$/ ? true : false)
  end

  def self.validateEmailDomain(email)
    mxRecs = self.getEmailMXRecords(email)
    retVal = ((mxRecs and !mxRecs.empty?) ? true : false)
    return retVal
  end

  def self.getEmailMXRecords(email)
    retVal = nil
    if(email =~ /@(.+)/)
      domain = $1
      Resolv::DNS.open { |dns|
        retVal = dns.getresources(domain, Resolv::DNS::Resource::IN::MX)
      }
    end
    return retVal
  end

  def self.validateEmail(email, validations=:full)
    retVal = true
    if(validations == :full or validations == :pattern)
      retVal = self.validateEmailPattern(email)
    end
    if(retVal and (validations == :full or validations == :domain))
      retVal = self.validateEmailDomain(email)
    end
    return retVal
  end

  # ------------------------------------------------------------------
  # INSTANCE METHODS
  # ------------------------------------------------------------------
	def initialize(smtpServer=SMTP_SERVER, smtpPort=SMTP_PORT)
		@smtpServer = smtpServer
		@smtpPort = smtpPort
		@mailFrom = nil
		@toList = []
		@otherHeaders = []
		@dateHeader = nil
		@fromHeader = nil
		@toHeader = nil
		@subjectHeader = nil
		@replyToHeader = nil
		@sendError = @sendWarning = nil
		@body = nil
	end

	def setHeaders(fromHeader, toHeader, subjectHeader, dateHeader=Time.now().to_rfc822())
		@fromHeader, @toHeader, @subjectHeader, @dateHeader = fromHeader, toHeader, subjectHeader, dateHeader
		@replyToHeader = @fromHeader
		return
	end

	def addHeader(header)
		@otherHeaders << header
		return
	end

	def setBody(body)
		@body = body
	end

	def setMailFrom(mailFrom)
		@mailFrom = mailFrom
	end

	def setRecipients(recipientsArray)
		@toList = recipientsArray
	end

	def addRecipient(recipient)
		@toList << recipient
	end

	def send()
    @sendError = @sendWarning = nil
		unless(self.isValid?())
      msg = "\n\nERROR: the email is incomplete. You need to have: the recipients list, the from/to/subject headers, and a body\n  mailFrom = #{@mailFrom}\n  toList = #{@toList}\n  dateHeader = #{@dateHeader}\n  fromHeader = #{@fromHeader}\n  toHeader = #{@toHeader}\n  subjectHeader = #{@subjectHeader}\n  body = #{@body}"
      @sendError = EmailFormatError.new(msg)
      raise @sendError
		end
		begin
			realBody = self.formatBody()
			smtp = ::Net::SMTP.new(@smtpServer, @smtpPort)
			smtp.start()
			smtp.sendmail(realBody, @mailFrom, @toList)
			begin
				smtp.finish()
			rescue IOError => ioerr # ignore if already closed, for 1.6->1.8 compatibility; save as a warning in case dev interested
        @sendWarning = ioerr
			end
		rescue Timeout::Error => terr # some problem communicating with the smtpHost, often wrong smtpHost being used
      msg = "\n\nFATAL ERROR: cannot communicate with the SMTP server at '#{@smtpServer}' on port '#{@smtpPort}'. Are those settings appropriate? Timed out trying to talk to that server."
      @sendError = terr
      $stderr.puts msg
		rescue => err
      msg = "\n\nFATAL ERROR: couldn't send the email! Here are details of the error:\n\n#{err.message}\n\n#{err.backtrace}\n"
      @sendError = err
      $stderr.puts msg
		end
		return (@sendError.nil?)
	end

	def formatBody()
		return 	"Date: #{@dateHeader}\nFrom: #{@fromHeader}\nReply-To: #{@replyToHeader}\nTo: #{@toHeader}\n" +
						((@otherHeaders.nil? or @otherHeaders.empty?) ? '' : (@otherHeaders.join("\n") + "\n") ) +
						"Subject: #{@subjectHeader}\n\n#{@body}\n\n"
	end

	def isValid?()
		unless(	@mailFrom.to_s.empty? or @toList.nil? or @toList.empty? or
						@dateHeader.to_s.empty? or @fromHeader.to_s.empty? or
						@toHeader.to_s.empty? or @subjectHeader.to_s.empty? or @body.to_s.empty?)
			return true
		else
			return false
		end
	end
end

end ; end
