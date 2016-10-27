#!/usr/bin/env ruby
 
# ##############################################################################
# REQUIRED LIBRARIES
# #############################################################################
require 'cgi'
require 'open3'
require 'brl/util/util'
require 'brl/util/textFileUtil'
require 'brl/genboree/constants'

module BRL ; module Genboree
  LandMark = Struct.new(:chrName, :chrStart, :chrStop)
  class LiveLFFDownload
    attr_accessor :userId, :refSeqId, :trkNames, :landmark, :doColHeaders
    attr_accessor :ioArray, :cmd, :errFile

    def initialize(userId, refSeqId, trkNames=[], landmark=nil)
      @userId, @refSeqId, @trkNames, @landmark = userId, refSeqId, trkNames, landmark
      @doColHeaders = true
      @errFile = nil
    end

    def setLandmark(chrName, chrStart=nil, chrStop=nil)
      @landmark = LandMark.new(chrName, chrStart, chrStop)
    end

    # _returns_ - Array of [cmdStdin, cmdStdout, cmdStderr]
    def doDownload()
      @cmd = "java -classpath $CLASSPATH -Xmx1800M org.genboree.downloader.AnnotationDownloader -b -w 650 -u #{@userId} -r #{@refSeqId} "
      @cmd << " -c " unless(@doColHeaders)
      @cmd = addTracksToCmd(@cmd)
      @cmd = addLandmarkToCmd(@cmd)
      @cmd << " 2> #{@errFile} " if(@errFile)
      $stderr.puts "\nAPI LFF DOWNLOAD CMD:    #{@cmd.inspect}\n\n"
      @ioArray = Open3.popen3(@cmd)
      return @ioArray
    end

    def self.cleanStderrStr(stderrStr)
      return stderrStr.gsub(/^STATUS:[^\n]+\n/, '')
    end

    # --------------------------------------------------------------------------
    # HELPERS
    # --------------------------------------------------------------------------
    def addTracksToCmd(cmdBase)
      trkNamesBuff = ''
      if(@trkNames and !@trkNames.empty?)
        trkNamesBuff << " -m '"
        @trkNames.each_index { |ii|
          escTrkName = CGI.escape(trkNames[ii])
          trkNamesBuff << escTrkName
          trkNamesBuff << ',' unless(ii >= (trkNames.size-1))
        }
        trkNamesBuff << "'"
      else # no track names? then do all
        trkNamesBuff << " -m all "
      end
      return cmdBase << trkNamesBuff
    end

    def addLandmarkToCmd(cmdBase)
      if(@landmark)
        cmdBase << " -n '#{@landmark.chrName}' "
        cmdBase << " -s #{@landmark.chrStart} " if(@landmark.chrStart)
        cmdBase << " -e #{@landmark.chrStop} " if(@landmark.chrStop)
      end
      return cmdBase
    end
  end # class LiveLFFDownload
end ; end # module BRL ; module Genboree
