require 'rubygems'
require 'erb'
require 'brl/util/textFileUtil'
require 'brl/genboree/dbUtil'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/toolPlugins/util/util.rb'
# retry load if facets 1.X doesn't work...try 2.X style
begin
  require 'facet/pqueue'
rescue LoadError => lerr
  begin
    require 'facets/pqueue'
  rescue LoadError => lerr2
     require 'pqueue'
  end
end
require 'brl/facets/facetsUtil'

include BRL::Genboree::ToolPlugins
include BRL::Genboree::ToolPlugins::Util


# Cross-version PQueue
class PQueue
  def setCompareProc(compareProc=lambda {|a,b| a > b})
    @gt = compareProc
  end
end

module BRL module Genboree ; module ToolPlugins; module Tools
  module NameSelectorTool  # module namespace to hold various classes (or even various tools)
    KGALIAS_ROOT_DIR = '/usr/local/brl/data/genboree/toolPlugins/resources/nameSelector'
    KGALIAS_VER_MAP = {
                        "10april2003" => "10april2003",
                        "mm6" => "mm6",
                        "mmFeb2003" => "mmFeb2003",
                        "mm7" => "mm7",
                        "mm8" => "mm8",
                        "rn4" => "rn4",
                        "rn2" => "rn2",
                        "rn3" => "rn3",
                        "hg17" => "hg17",
                        "mm5" => "mm5",
                        "hg18" => "hg18",
                        "rnJan2003" => "rnJan2003",
                        "rnJun2003" => "rnJun2003"
                      }

    class NameSelectorClass # an actual tool
      # DEFINE your about() method
      def self.about()
        return  {
                  :title => 'Select Annotations By Name',
                  :desc => 'Selects annotations from one or more tracks using their name column and a list of names/patterns of interest.',
                  :functions => self.functions()
                }
      end

      # DEFINE a method that describes the characteristics of each function (tool) available.
      # The keys in the returned hash must match a function name in this class.
      # The :input description key contains the custom parameters (inputs) to the tool.
      # However, some, such as expname, refSeqId, etc, are ~universal.
      def self.functions()
        return  {
          :selectAnnosByName =>     # Must match a function/tool name in this class
          {
            :title => 'Name-Based Annotation Selection',
            :desc => 'Selects annotations from one or more tracks using their name column and a list of names/patterns of interest.',
            :displayName => '4) Name-Based Annotation Selection', # Displayed in tool-list HTML
            :internalName => 'nameSelector',    # Internal reference/key
            :autoLinkExtensions => { 'lff.gz' => 'lff.gz' },  # List all src file extensions => dest file extensions.
            :resultFileExtensions => { 'selectedAnnos.lff.gz' => true, 'nameList.txt.gz' => true },    # List all result files accessible via the output page.
            # :INPUT :>
            # These *must* match the form element ids.
            # They should not be missing in the form, with some special exceptions.
            # 1) Items listed here will be saved in the PARAMS.dat file for this task.
            #    So make sure you include all the user's parameters from the UI.
            # 2) The ":desc" will be used to display the name of the parameter to the *user*.
            #    Make it consistent with the UI and end it with a : is recommended.
            # 3) The ":paramDisplay" indicated the order in which to display the parameter to
            #    the user when viewing job results. -1 means "don't display" and is used for
            #    internal-only parameters the user shouldn't actually see. NO TIES.
            :input =>
            {
              :expname  =>  { :desc => "Job Name:", :paramDisplay => 1 },
              :refSeqId => { :desc => "Genboree uploadId for input LFF data:", :paramDisplay => -1 },
              :userId => { :desc => "Genboree userId for submitting user:", :paramDisplay => -1  },
              :annoNames => { :desc => "Names and patterns to select:", :paramDisplay => 3  },
              :useGeneAliases => { :desc => "Use known gene aliases to expand search:", :paramDisplay => 4 },
              :selectMode => { :desc => "Search mode to employ:", :paramDisplay => 5 },
              :trackClass => { :desc => "Output track class:", :paramDisplay => 6 },
              :trackType => { :desc => "Output track type:", :paramDisplay => 7 },
              :trackSubtype => { :desc => "Output track subtype:", :paramDisplay => 8 },
              # Special one: added *after* pre-processing form data. Will be added here in a form
              # the user can understand when displaying their params.
              :trackList => { :desc => "Tracks to Search:", :paramDisplay => 2 }
            }
          }
        }
      end

      # MAKE NAME LIST FILE
      def makeNameListFile(output, annoNames, filesToCleanUp)
        nameListFile = output + ".nameList.txt"
        writer = BRL::Util::TextWriter.new(nameListFile)
        annoNames.each_line { |aliasesStr|
          writer.puts aliasesStr.strip
        }
        writer.close()
        filesToCleanUp << nameListFile
        return nameListFile
      end

      def makeTrackLFFs(outputDir, trackList, refSeqId, userId, filesToCleanUp)
        trackLFFs = []
        # Let's put the auto-lff in the actual tool execution directory! Much more convenient and localized.
        trackList.each { |track|
          trackName = track[0]
          cleanTrack = trackName.gsub( BAD_CHARS_RE, BAD_CHARS_REPLACEMENT ).gsub(/ /, '\ ') # Make the track ultra-safe for DIR-naming
          trackLFF = "#{outputDir}/#{userId}_#{refSeqId}_#{cleanTrack}_#{Time.now.to_i}.lff"
          commandStr = "java -classpath #{JCLASS_PATH} -Xmx1800M " +
                       " org.genboree.downloader.AnnotationDownloader " +
                       " -u #{userId} " +
                       " -r '#{refSeqId}' " +
                       " -m '#{trackName}' " +
                       " > #{trackLFF} " +
                       " 2> #{trackLFF}.err "
          $stderr.puts "\n\nNAME SELECTOR: track-download command:\n\n#{commandStr}\n\n"
          cmdOk = system(commandStr)
          unless(cmdOk)
            raise "\n\nERROR: NameSelectorClass#makeTrackLFFs => error with calling annotation downloader.\n" +
                  "    - exit code: #{$?}\n" +
                  "    - command:   #{commandStr}\n"
          else
            trackLFFs << trackLFF
            filesToCleanUp << trackLFF
            filesToCleanUp << "#{trackLFF}.err"
          end
        }
        return trackLFFs
      end

      # MAKE TRACK LIST
      def makeTrackList(options)
        trackListQueue = PQueue.new()
        trackListQueue.setCompareProc(Proc.new(){|aa,bb| aa[1] < bb[1]} )
        # Go through keys of options
        options.each_key { |param|
          paramStr = param.to_s
          # If key is a track-like param
          next unless(paramStr =~ /^trackName_\d+$/)
          # Parse it, keep if selected, reject otherwise
          values = options[param].split(/,/)
          values.map! {|xx| xx.strip}
          next unless(values[1] =~ /^true$/i)
          trackListQueue.push( [ values[0], values[2].to_i ] )
        }
        return trackListQueue.pop_array()
      end

      # FIND APPROPRIATE KGALIAS FILE IF POSSIBLE
      def findKgAliasFile(refSeqId)
        kgAliasFile = nil
		    dbrcFile = ENV['DB_ACCESS_FILE'].dup.untaint
        # Configure genboree database connection info
        # Load Genboree Config File (has the dbrcKey in it to use for this machine)
		    genbConfig = GenboreeConfig.new()
		    genbConfig.loadConfigFile()
		    dbu = BRL::Genboree::DBUtil.new(genbConfig.dbrcKey, nil, dbrcFile)
        # Connect to genboree database
		    dbu.connectToMainGenbDb()
        # Get the refseq_version for this refSeqId
        results = dbu.selectRefseqVersionByRefSeqID(refSeqId)
        unless(results.nil? or results.empty?())
          refSeqVer = results[0]['refseq_version']
          refSeqVer.downcase!
          # Use refseq_version to find a kgAlias file, if possible
          if(KGALIAS_VER_MAP.key?(refSeqVer))
            kgAliasFile = "#{KGALIAS_ROOT_DIR}/#{KGALIAS_VER_MAP[refSeqVer]}/kgAlias.txt.gz"
          end
        end
        dbu.clear()
        return kgAliasFile
      end

      # THIS IS THE FUNCTION THAT RUNS THE ACTUAL TOOL.
      # Here, it is called 'selectAnnosByName', as returned by self.functions()
      # NOTE: It is also possible to *do* the actual tool here. That might not
      # be a good idea, for organization purposes. Keep the tool *clean* of this
      # framework/convention stuff and make it it's own class or even program.
      def selectAnnosByName( options )
        # Keep track of files we want to clean up when finished
        filesToCleanUp = []

        # REQUIRED: get your command-line (or method-call) options together to
        # build a proper call to the wrapped tool.
        # Plugin options
        expname = options[:expname]
        refSeqId = options[:refSeqId]
        userId = options[:userId]
        annoNames = options[:annoNames]
        useGeneAliases = options.key?(:useGeneAliases)
        selectMode = options[:selectMode]

        # Output options
        outputClass = options[:trackClass]
        outputType = options[:trackType]
        outputSubtype = options[:trackSubtype]
        output = options[:output]

        # ENSURE output dir exists (standardized code)
        output =~ /^(.+)\/[^\/]*$/
        outputDir = $1
        checkOutputDir( outputDir )

        # PREPARATION CODE:
        #
        # Make trackList for track orders
        trackList = self.makeTrackList(options)
        if(trackList.empty?)
          errMsg = "\n\nNo tracks to process.\n\n"
          $stderr.puts "NAME SELECTOR ERROR: Name Selector has no input tracks."
          options.each_key { |kk|
            $stderr.puts " - #{kk} => #{options[kk].inspect}"
          }
          raise errMsg
        end

        # Add trackList as a sensible string to options for display to user and then save options.
        trackListStr = ''
        tcount = 0
        trackList.each { |track| trackListStr += "#{tcount+=1}. #{track[0]}\n" }
        options[:trackList] = trackListStr

        # SAVE PARAM DATA (marshalled ruby)
        BRL::Genboree::ToolPlugins::Util::saveParamData(options, output, NameSelectorClass.functions()[:selectAnnosByName][:input])

        # CREATE ANY OTHER FILES you need. For example, files with commands or
        # lists of things in tool-specific formates, etc.
        # Get separate lff files for all source tracks.
        # Make namesHash to feed to tool class
        nameListFile = makeNameListFile(output, annoNames, filesToCleanUp)

        # GET ANY DNA SEQUENCE file the tool may need also.
        # This is not always necessary.

        # DUMP n LFF FILES FOR n INPUT TRACKS
        trackLFFs = self.makeTrackLFFs(outputDir, trackList, refSeqId, userId, filesToCleanUp)
        trackLFFsStr = trackLFFs.join(',')
        if(trackLFFs.empty?)
          errMsg = "\n\nNo track files to process.\n\n"
          $stderr.puts "NAME SELECTOR ERROR: Name Selector has no input track files."
          options.each_key { |kk|
            $stderr.puts " - #{kk} => #{options[kk].inspect}"
          }
          raise errMsg
        end

        # DECIDE ON kgAlias FILE
        if(useGeneAliases)
          kgAliasFile = self.findKgAliasFile(refSeqId)
        else
          kgAliasFile = nil
        end

        # BUILD COMMAND to call
        cleanOutput = output.gsub(/ /, '\ ') # you need to use this to deal with spaces in files (which are ok!)
        selectorCmd = "#{RUBY_APP} #{LFF_NAMESELECTOR_APP} -f '#{CGI.escape(trackLFFsStr)}' -n '#{CGI.escape(nameListFile)}' " +
                      " -m #{selectMode} " +
                      " -c '#{CGI.escape(outputClass)}' -t '#{CGI.escape(outputType)}' -u '#{CGI.escape(outputSubtype)}' "
        selectorCmd += " -k '#{kgAliasFile}' " unless(kgAliasFile.nil?)
        selectorCmd += " > #{cleanOutput}.selectedAnnos.lff 2> #{cleanOutput}.selectedAnnos.err "

        $stderr.puts "#{Time.now.to_s} NameSelectorTool#selectAnnosByName(): command is:\n    #{selectorCmd}\n" # for logging

        # EXECUTE *ACTUAL* TOOL:
        cmdOK = system( selectorCmd )
        # NOTE: use ESCcaped file path! (command line call used)
        filesToCleanUp << "#{cleanOutput}.selectedAnnos.lff"  # CLEAN UP: out file from name selection.
        filesToCleanUp << "#{cleanOutput}.selectedAnnos.err"  # CLEAN UP: err file from name selection.

        # CHECK RESULT OF TOOL. Eg this might be a command code ($? after a system() call), nil/non-nil,
        # or whatever. If ok, process any raw tool output files if needed. If not ok, put error info.
        noAnnosSelected = false
        if(cmdOK) # Command succeeded
          # PROCESS TOOL OUTPUT. If needed. For example, to make it an HTML page, or more human-readable.
          # Or to create LFF(s) from it so it can be uploaded.
          # Not all tools need to process tool output (e.g. if tool dumps LFF directly or is not upload-related)
          #
          # - open output file(s)
          # - open new output file(s)
          # - process output and close everything

          # UPLOAD DATA into Genboree as LFF.
          # Sometimes the user chooses to do this or not. Sometimes it is a
          # required step for the tool. Sometimes there is one file to upload.
          # Sometimes there are many. Deal with the decisions and then the
          # uploading in the following *standardized* way:
          # NOTE: use UNescaped file path!
          BRL::Genboree::ToolPlugins::Util::SeqUploader.uploadLFF( "#{output}.selectedAnnos.lff", refSeqId, userId )
        else # Command failed
          # Open any files you need to in order to get informative errors or any
          # data that is available.
          # Then:
          #
          # Raise error for framework to handle, with this error.
          errMsg = "\n\nThe Name Selection program failed and did not fully complete.\n\n"
          $stderr.puts  "NAME SELECTOR ERROR: Name Selector died: '#{errMsg.strip}'\n"
          options.keys.sort.each { |key| $stderr.puts "  - #{key} = #{options[key]}\n" }
          raise errMsg
        end

        # CLEAN UP CALL. This is *standardized*, call it at the end.
        cleanup_files(filesToCleanUp) # Gzips files listed
        return [ ]
      end

    end # class NameSelectorClass
  end # module NameSelectorTool
end ; end ; end ; end
