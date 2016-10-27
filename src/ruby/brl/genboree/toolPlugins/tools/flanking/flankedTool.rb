# ##############################################################################
# LIBRARIES
# ##############################################################################
require 'erb'
require 'yaml'
require 'cgi'
require 'json'
require 'brl/util/textFileUtil'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/toolPlugins/util/util.rb'
include BRL::Genboree::ToolPlugins
include BRL::Genboree::ToolPlugins::Util

# ##############################################################################
# NAMESPACE
# - a.k.a. 'module'
# - This is *very* important.
# - How your tool is expected to be found.
# - First part is *standard* ; second is the module for your tool within Genboree
# - Must match the directory location + "Tool"
# - //brl-depot/.../brl/genboree/toolPlugins/tools/tiler/
# ##############################################################################
module BRL module Genboree ; module ToolPlugins; module Tools
  # Your tool's specific namespace
  module FlankedDetectorTool    # module namespace to hold various classes (or even various tools)

  # ##############################################################################
  # TOOL WRAPPER
  # - a specific class with some required methods
  # - this class wraps the tool execution and is 'registered' with the framework
  # ##############################################################################
    class FlankedDetectorClass  # an actual tool

      # ---------------------------------------------------------------
      # REQUIRED METHODS
      # ---------------------------------------------------------------
      # DEFINE your about() method
      def self.about()
        return  {
                  :title => 'Find Flanked Annotations',
                  :desc => 'Detect annotations in one track that are flanked by annotations from 1+ other classes.',
                  :functions => self.functions()
                }
      end

      # DEFINE functions(), an info-providing method.
      # - describes the characteristics of the function (tool) available
      # - keys in the returned hash must match a method name in this class.
      # - :input info key contains the custom parameters (inputs) to the tool.
      # - many other info keys, such as expname, refSeqId, etc, are universal
      #   and must be present
      def self.functions()
        return  {
          :findFlankedAnnos =>     # Must match a method name in this class (tool execution method)
          {
            :title => 'Find Flanked Annotations',
            :desc => 'Detect annotations in one track that are flanked by annotations from 1+ other classes.',
            :displayName => '5) Flanked Anno Detector',     # Displayed in tool-list HTML to user
            :internalName => 'flankedDetector',             # Internal reference/key
            # List all src file extensions => dest file extensions:
            :autoLinkExtensions => { 'lff.gz' => 'lff.gz' },
            # List all output extensions that will be available to the user:
            # - NOTE: the BASE of these files is expected to be the JOB NAME provided by the user.
            # - it is an *extension*, so a . will join it to the file BASE
            # - make sure to adhere to this convention.
            :resultFileExtensions =>  {
                                        'flanked.lff.gz' => true,
                                      },
            # :INPUT parameters
            # - These *must* match the form element ids EXACTLY.
            # - Form element data is pre-processed a bit before you get it.
            # - They CANNOT be missing in the form nor missing here, unless noted.
            :input =>
            {
              # Standard: job name and database id
              :expname  =>  { :desc => "Job Name: ", :paramDisplay => 1 },
              :refSeqId => { :desc => "Genboree uploadId for input LFF data: ", :paramDisplay => -1 },
              # Input track...framework notices _lff and provides the _lff file for your tool.
              :template_lff => { :desc => "Track find flanked annos in: ", :paramDisplay => -1},
              # Exception: this following is created by the framework for
              # _lff form data elements. We use this to keep the existing parameter, since framework changes any *_lff NVPs.
              :template_lff_ORIG => { :desc => "Track find flanked annos in: ", :paramDisplay => 2},

              # List of tracks to use to detected flanked annotations.
              # - input arrives as JSON array of URL-escape tracks.
              :secondTrackJson => { :desc => "Tracks to use for flanking: ", :paramDisplay => -1},
              # - saved in human-readable format in the following option:
              :trackList => { :desc => "Tracks to use for flanking: ", :paramDisplay => 3},

              # Tool-specific parameters:
              :radius => { :desc => "Radius around anno to look for flanking annos: ", :paramDisplay => 3 },
              :anyOrAll => { :desc => "Flanked by annos from ANY track or ALL tracks? ", :paramDisplay => 4 },
              :oneEndOnly => { :desc => "Flanked by only one end is good enough? ", :paramDisplay => 5},
              :nonFlanking => { :desc => "Find non-flanked annotation? ", :paramDisplay => 6},

              # Output track parameters:
              :trackClass => { :desc => "Flanked track class: ", :paramDisplay => 12 },
              :trackType => { :desc => "Flanked track type: ", :paramDisplay => 13 },
              :trackSubtype => { :desc => "Flanked track subtype: ", :paramDisplay => 14 },
            }
          }
        }
      end

      def getSecondTrackList(options)
        secondTracksStr = options[:secondTrackJson]
        # It's escaped explicitly for quoting-protection. Unescape it.
        secondTracksStr = CGI.unescape(secondTracksStr)
        $stderr.puts "secondTracksStr: #{secondTracksStr.inspect}"
        secondTracks = JSON.parse(secondTracksStr)
        $stderr.puts "secondTracks array: #{secondTracks.inspect}"
        secondTracks.map! {|xx| CGI.unescape(xx) }
        if(secondTracks.empty?)
          errMsg = "\n\nNo tracks provided for flanking annotations.\n\n"
          $stderr.puts "FLANKED ANNOS DETECTOR ERROR: No tracks provided as source of flanking annotations."
          options.each_key { |kk|
            $stderr.puts " - #{kk} => #{options[kk].inspect}"
          }
          raise errMsg
        end
        return secondTracks
      end

      def makeTrackLFFs(outputDir, secondTracksList, refSeqId, userId, filesToCleanUp)
        trackLFFs = []
        # Let's put the auto-lff in the actual tool execution directory! Much more convenient and localized.
        secondTracksList.each { |trackName|
          cleanTrack = CGI.escape(trackName) # Make the track ultra-safe for DIR-naming
          trackLFF = "#{outputDir}/#{userId}_#{refSeqId}_#{cleanTrack}_#{Time.now.to_i}.lff"
          commandStr = "java -classpath #{JCLASS_PATH} -Xmx1800M " +
                       " org.genboree.downloader.AnnotationDownloader " +
                       " -u #{userId} " +
                       " -r '#{refSeqId}' " +
                       " -m '#{CGI.escape(trackName)}' " +
                       " > #{trackLFF} " +
                       " 2> #{trackLFF}.err "
          $stderr.puts "\n\nFLANKED ANNOS DETECTOR: track-download command:\n\n#{commandStr}\n\n"
          cmdOk = system(commandStr)
          unless(cmdOk)
            raise "\n\nERROR: FlankedDetectorClass#makeTrackLFFs => error with calling annotation downloader.\n" +
                  "    - exit code: #{$?}\n" +
                  "    - command:   #{commandStr}\n"
          else
            trackLFFs << trackLFF
            filesToCleanUp << trackLFF
            filesToCleanUp << "#{trackLFF}.err"
          end
        }
        if(trackLFFs.empty?)
          errMsg = "\n\nNo tracks provided for flanking annotations.\n\n"
          $stderr.puts "FLANKED ANNOS DETECTOR ERROR: No tracks provided as source of flanking annotations."
          options.each_key { |kk|
            $stderr.puts " - #{kk} => #{options[kk].inspect}"
          }
          raise errMsg
        end

        return trackLFFs
      end

      # MAKE TRACK LIST STR
      # - this human-readable string is what will be saved in the parameter file
      def saveTrackListStr(secondTracksList, options)
        trackListStr = ''
        tcount = 0
        secondTracksList.each { |track| trackListStr += "#{tcount+=1}. #{track}\n" }
        options[:trackList] = trackListStr
        return options
      end

      # ---------------------------------------------------------------
      # TOOL-EXECUTION METHOD
      # - THIS IS THE FUNCTION THAT RUNS THE ACTUAL TOOL.
      # - Must match the top-level hash key in self.functions() above.
      # ---------------------------------------------------------------
      # - Here, it is called 'findFlankedAnnos', as returned by self.functions()
      # - Argument must be 'options', a hash with form data and a couple extra
      #   entries added by the framework. Get your data from there.
      # - NOTE: It is also possible to *do* the actual tool here. That might not
      #   be a good idea, for organization purposes. Keep the tool *clean* of this
      #   framework/convention stuff and make it it's own class or even program.
      def findFlankedAnnos( options )
        # Keep track of files we want to clean up (gzip) when finished
        filesToCleanUp = []

        # -------------------------------------------------------------
        # GATHER NEEDED PARAMETERS
        # - get your command-line (or method-call) options together to
        #   build a proper call to the wrapped tool.
        # -------------------------------------------------------------
        # Plugin options
        expname = options[:expname]
        refSeqId = options[:refSeqId]
        userId = options[:userId]
        # Framework has turned this into a file-path to the LFF:
        template_lff = options[:template_lff]
        # File path where input data is and where output goes:
        output = options[:output]

        # Flanking options
        secondTracksList = getSecondTrackList(options)
        radius = options[:radius].to_i
        requireAll = options[:anyOrAll] == 'all' ? true : false
        oneEndOnly = options[:oneEnd] == 'one' ? true : false
        nonFlanking = !(options[:nonFlanking].nil? and options[:nonFlanking] !~ /\S/)

        # Output options
        outputTrackClass = options[:trackClass]
        outputTrackType = options[:trackType]
        outputTrackSubtype = options[:trackSubtype]

        # -------------------------------------------------------------
        # ENSURE output dir exists (standardized code)
        # NOTE: "output" is UNescaped file path. MUST pay attention where you use an UNescaped path
        #       and where you use an ESCaped path. Generally:
        #       - MUST use UNescaped path when making use of Ruby calls. True file name.
        #       - Use ESCaped path when using command-line calls. "sh" will interpret incorrectly otherwise.
        # -------------------------------------------------------------
        output =~ /^(.+)\/[^\/]*$/
        outputDir = $1
        checkOutputDir( outputDir )
        # NOTE: this is an ESCaped version of the file path, suitable (more or less)
        #       for use on the command line. This is not fully escaped however, on purpose.
        #       It is expected that the weird chars (`'; for eg) are not permitted by the
        #       UI for job names. Unfortunately, ' ' (space) is NOT a weird character, so
        #       we must escape it.
        cleanOutput = output.gsub(/ /, '\ ') # you need to use this to deal with spaces in files (which are ok!)

        # Add trackList as a sensible string to options for display to user and then save options.
        options = saveTrackListStr(secondTracksList, options)

        # -------------------------------------------------------------
        # SAVE PARAM DATA (marshalled ruby)
        # -------------------------------------------------------------
        BRL::Genboree::ToolPlugins::Util::saveParamData(options, output, FlankedDetectorClass.functions()[:findFlankedAnnos][:input])

        # -------------------------------------------------------------
        # PREPARATION CODE:
        # - Prepare data prior to running your tool

        # Create LFF file with data from secondary tracks in it
        trackLFFs = self.makeTrackLFFs(outputDir, secondTracksList, refSeqId, userId, filesToCleanUp)
        trackLFFsStr = trackLFFs.join(',')

        # Clean up the input file too
        filesToCleanUp << "#{template_lff}"

        # -------------------------------------------------------------
        # EXECUTE WRAPPED TOOL
        # -------------------------------------------------------------
        # Prep command string:
        # - use ESCaped version cleanOutput, because this is a shell-call.
        # First, prep the secondary track args string
        secondTracksArg = ''
        secondTracksList.each {|xx| secondTracksArg << "#{CGI.escape(xx)},"}
        secondTracksArg.chomp!(',')

        flankingCmd = "flanking.rb -f #{CGI.escape(template_lff)} -s '#{secondTracksArg}' -l '#{CGI.escape(trackLFFsStr)}' -o #{cleanOutput}.flanked.lff " +
                      " -r #{radius} " +
                      " -c '#{CGI.escape(outputTrackClass)}' -n '#{CGI.escape(outputTrackType)}:#{CGI.escape(outputTrackSubtype)}' "
        flankingCmd << " -e " if(oneEndOnly)
        flankingCmd << " -a " if(requireAll)
        flankingCmd << " -x " if(nonFlanking)
        flankingCmd << " > #{cleanOutput}.flanked.out 2> #{cleanOutput}.flanked.err"
        $stderr.puts "#{Time.now.to_s} FlankedDetector#findFlankedAnnos(): FLANKED command is:\n    #{flankingCmd}\n" # for logging

        # Run tool command:
        cmdOK = system( flankingCmd )
        $stderr.puts "#{Time.now.to_s} FlankedDetector#findFlankedAnnos(): FLANKED command exit ok? #{cmdOK.inspect}\n"
        # NOTE: use ESCaped version cleanOutput, because clean up is a shell-call.
        filesToCleanUp << "#{cleanOutput}.flanked.out"
        filesToCleanUp << "#{cleanOutput}.flanked.err"
        # -------------------------------------------------------------
        # CHECK RESULT OF TOOL.
        # - Eg this might be a command code ($? after a system() call), nil/non-nil,
        #   or whatever. If ok, process any raw tool output files if needed. If not ok, put error info.
        # -------------------------------------------------------------
        if(cmdOK) # Command succeeded
          # -------------------------------------------------------------
          # POST-PROCESS TOOL OUTPUT. If needed.
          # - For example, to make it an HTML page, or more human-readable.
          # - Or to create LFF(s) from tool so it can be uploaded.
          # - Not all tools need to process tool output (e.g. if tool dumps LFF directly
          #   or is not upload-related)
          #
          # - open output file(s)
          # - open new output file(s)
          # - process output and close everything

          # -------------------------------------------------------------
          # GZIP SUCCESSFUL OUTPUT FILES.
          # - You *must* register your output files to save space.
          # - Some output can be huge and you don't know that the user hasn't
          #   selected their 10 million annos track to work on.
          # NOTE: use ESCaped version cleanOutput, because clean up is a shell-call.
          # Tool strips the .lff before making these tmp files...so we need to do that too...
          template_noLff = template_lff.gsub(/\.lff$/, "")
          filesToCleanUp << "#{template_noLff}.intersect.lff" # intersect tool tmp file
          filesToCleanUp << "#{template_noLff}.ends.lff" # intersect tool tmp file

          # -------------------------------------------------------------
          # - UPLOAD DATA into Genboree as LFF.
          #   Sometimes the user chooses to do this or not. Sometimes it is a
          #   required step for the tool. Sometimes there is one file to upload.
          #   Sometimes there are many. Deal with the decisions and then the
          #   uploading in the following *standardized* way:
          BRL::Genboree::ToolPlugins::Util::SeqUploader.uploadLFF( "#{output}.flanked.lff", refSeqId, userId )
          filesToCleanUp << "#{cleanOutput}.flanked.lff"
        else # Command failed
          # Open any files you need to in order to get informative errors or any
          # data that is available.
          # Then:
          #
          # Raise error for framework to handle, with this error.
          errMsg = "\n\nThe Flanked Annotation Detection program failed and did not fully complete.\n\n"
          $stderr.puts  "FLANKED ANNOS DETECTOR ERROR: flanking died: '#{errMsg.strip}'\n"
          options.keys.sort.each { |key| $stderr.puts "  - #{key} = #{options[key]}\n" }
          raise errMsg
        end

        # -------------------------------------------------------------
        # CLEAN UP CALL. This is *standardized*, call it at the end.
        # -------------------------------------------------------------
        cleanup_files(filesToCleanUp) # Gzips files listed
        return [ ]
      end
    end # class FlankedDetectorClass
  end # module FlankedDetectorTool
end ; end ; end ; end # end namespace
