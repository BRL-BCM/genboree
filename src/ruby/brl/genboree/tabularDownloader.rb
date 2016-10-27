#!/usr/bin/env ruby
require 'json'
require 'fileutils'
require 'brl/util/util'
require 'brl/genboree/rest/data/tabularLayoutEntity'

module BRL ; module Genboree                 # <- resource classes must be in this namespace
  #  ==Overview
  #  This class prepares the call to the Java class TabularDownloader
  class TabularDownload
    attr_accessor :refSeqId, :trkNames, :landmark, :layout, :userId, :errFile
    attr_accessor :ioArray, :cmd
    
    # CONSTRUCTOR.  Create a TabularDownload object based on the attributes provided.
    # [+userId+]      ID of user making the request.
    # [+refSeqId+]    RefSeqId of database to be queried.
    # [+trkNames+]    Tracks to be included in the result.  Either single track as a +String+
    #                 or multiple track names as an +Array+ are accepted.
    # [+layout+]      The layout can be provided as either a string in the case of specifying
    #                 a layout stored in the database, or as a TabularLayoutEntity in the case
    #                 of describing the layout manually.  The addLayoutToCmd method will check
    #                 for both cases.
    # [+landmark+]    [optional; default = nil] Can provide the landmark unescaped.
    # [+returns+]     Instance of +TabularDownload+
    def initialize(userId, refSeqId, trkNames, layout, landmark = nil)
      @userId, @refSeqId, @trkNames, @landmark, @layout = userId, refSeqId, trkNames, landmark, layout
      @errFile = nil
    end

    # [+returns+] Array of [cmdStdin, cmdStdout, cmdStderr]
    def doDownload()
      @cmd = "java org.genboree.downloader.TabularDownloader --refseq=#{@refSeqId} --user=#{@userId} "
      if(@trkNames.is_a?(Array))
        @trkNames.each{|trackName|
          @cmd = addTrackToCmd(@cmd,trackName)
        }
      else
        @cmd = addTrackToCmd(@cmd,@trkNames)
      end
      @cmd = addLandmarkToCmd(@cmd)
      @cmd = addLayoutToCmd(@cmd)
      @cmd << " 2>#{@errFile}" unless(@errFile.nil?)
      
      $stderr.puts "\nAPI TABULAR DOWNLOAD CMD:    #{@cmd.inspect}\n\n"
      @ioArray = Open3.popen3(@cmd)
      return @ioArray
    end

    # --------------------------------------------------------------------------
    # HELPERS
    # --------------------------------------------------------------------------
    
    # [+cmdBase+]   Incomplete Java command
    # [+trackName+] Track name to be appended.
    # [+returns+]   Java command appended with 'trackName' option.
    def addTrackToCmd(cmdBase,trackName)
      return cmdBase << "--trackName=#{trackName.inspect} "
    end
    
    # [+cmdBase+]  Incomplete Java command
    # [+returns+]  Java command appended with 'landmark' option.
    def addLandmarkToCmd(cmdBase)
      if(@landmark.nil? == false)
        cmdBase << " --landmark=#{@landmark.inspect} "
      end
      return cmdBase
    end
    
    # [+cmdBase+]  Incomplete Java command 
    # [+returns+]  Java command appended with 'layout' option.
    def addLayoutToCmd(cmdBase)
      if(@layout.is_a?(BRL::Genboree::REST::Data::TabularLayoutEntity))
        # We must not include the standard Genboree Wrapper here or the
        # downloader will not know how to handle this JSON, also we must
        # remove all line feeds (\n) because they screw up the Java side
        # JSON parsing.
        @layout.doWrap = false
        cmdBase << " --layout=#{@layout.to_json.inspect.gsub("\\n", "")} "
      elsif(@layout.is_a?(String))
        cmdBase << " --layoutName=#{@layout.inspect} "
      end
      return cmdBase
    end
  end #class TabularDownload
end ; end # module BRL ; module Genboree 
