# ##############################################################################
# LIBRARIES
# ##############################################################################
require 'cgi'
require 'erb'
require 'yaml'
require 'json'
require 'rein'
require 'brl/util/textFileUtil'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/toolPlugins/util/util.rb'
require 'brl/genboree/toolPlugins/util/json2reinRule.rb'
include BRL::Genboree::ToolPlugins
include BRL::Genboree::ToolPlugins::Util

# ##############################################################################
# NAMESPACE
# - a.k.a. 'module'
# - This is *very* important.
# - How your tool is expected to be found.
# - First part is *standard* ; second is the module for your tool within Genboree
# - Must match the directory location + "Tool"
# - //brl-depot/.../brl/genboree/toolPlugins/tools/lffSelector/
# ##############################################################################
module BRL module Genboree ; module ToolPlugins; module Tools
  # Your tool's specific namespace
  module LffSelectorTool    # module namespace to hold various classes (or even various tools)

  # ##############################################################################
  # TOOL WRAPPER
  # - a specific class with some required methods
  # - this class wraps the tool execution and is 'registered' with the framework
  # ##############################################################################
    class LffSelectorClass  # an actual tool

      # ---------------------------------------------------------------
      # REQUIRED METHODS
      # ---------------------------------------------------------------
      # DEFINE your about() method
      def self.about()
        return  {
                  :title => funcs[:selectAnnos][:title],
                  :desc => funcs[:selectAnnos][:desc],
                  :functions => funcs
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
          :selectAnnos =>     # Must match a method name in this class (tool execution method)
          {
            :title => 'Select Annotations',
            :desc => 'Selects annotations according to user-provided criteria.',
            :displayName => '1) Annotation Selector', # Displayed in tool-list HTML to user
            :internalName => 'lffSelector',           # Internal reference/key
            # List all src file extensions => dest file extensions:
            :autoLinkExtensions => { 'lff.gz' => 'lff.gz' },
            # List all output extensions that will be available to the user:
            # - NOTE: the BASE of these files is expected to be the JOB NAME provided by the user.
            # - it is an *extension*, so a . will join it to the file BASE
            # - make sure to adhere to this convention.
            :resultFileExtensions =>  {
                                        'selected.lff.gz' => true,
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
              :userId => { :desc => "Genboree userId for submitting user:", :paramDisplay => -1  },

              # Special one: added *after* pre-processing form data. Will be added here in a form
              # the user can understand when displaying their params.
              :trackList => { :desc => "Tracks to Search:", :paramDisplay => 2 },

              # Input track...framework notices _lff and provides the _lff file for your tool.
              # - NONE, several tracks are expected
              # Exception: this following is created by the framework for
              # _lff form data elements.
              # - NONE, several tracks are epxected
              :allAny => { :desc => "Match ALL rules or ANY rule: ", :paramDisplay => 3},
              :rulesJson => { :desc => "JSON corresponding to selection rules: ", :paramDisplay => -1 },

              # Tool-specific parameters:
              # - NONE

              # Output track parameters:
              :trackClass => { :desc => "Selected annos track class: ", :paramDisplay => 4 },
              :trackType => { :desc => "Selected annos track type: ", :paramDisplay => 5 },
              :trackSubtype => { :desc => "Selected annos track subtype: ", :paramDisplay => 6 },
            }
          }
        }
      end

      # Get a LIST of tracks.
      # - in this tool, there is no track order, so no need for a Priority
      #   Queue or other clever data structures for the track list.
      def makeTrackList(options)
        trackList = []
        # Go through keys of options
        options.each_key { |param|
          paramStr = param.to_s
          # If key is a track-like param
          next unless(paramStr =~ /^trackName_\d+_chkbx$/)
          # Parse it, keep if selected, reject otherwise
          trackList << options[param]
        }
        return trackList
      end

      # Make rules file from JSON string
      def makeRulesFile(allAny, json, output, filesToCleanUp)
        # Which resolution type to use?
        resolutionType = (allAny.downcase == 'any' ? Rein::RuleSpecObj::ANY_REQUIRED : Rein::RuleSpecObj::ALL_REQUIRED)
        # Parse JSON object to Rein ruleSpec object
        json2rein = JSON2ReinRule.new(resolutionType)
        ruleSpec = json2rein.parseJsonStr(json)
        # Get rule spec as YAML
        rulesYaml = ruleSpec.to_yaml()
        # Dump YAML to file
        ruleFile = output + ".rules.yaml"
        writer = BRL::Util::TextWriter.new(ruleFile)
        writer.puts rulesYaml
        writer.close()
        filesToCleanUp << ruleFile
        return ruleFile
      end

      # Make track LFF file
      def makeTrackLFFs(outputDir, trackList, refSeqId, userId, filesToCleanUp)
        trackLFFs = []
        # Let's put the auto-lff in the actual tool execution directory! Much more convenient and localized.
        trackList.each { |track|
          trackName = track
          cleanTrack = CGI.escape(trackName) # Make the track ultra-safe for DIR-naming
          trackLFF = "#{outputDir}/#{userId}_#{refSeqId}_#{cleanTrack}_#{Time.now.to_i}.lff"
          commandStr = "java -classpath #{JCLASS_PATH} -Xmx1800M " +
                       " org.genboree.downloader.AnnotationDownloader " +
                       " -u #{userId} " +
                       " -r '#{refSeqId}' " +
                       " -m '#{CGI.escape(trackName)}' " +
                       " > #{trackLFF} " +
                       " 2> #{trackLFF}.err "
          $stderr.puts "\nANNO SELECTOR: track-download command:\n\n#{commandStr}\n\n"
          cmdOk = system(commandStr)
          unless(cmdOk)
            raise "\n\nERROR: LffSelectorClass#makeTrackLFFs => error with calling annotation downloader.\n" +
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

      # Combine track LFFs into one big LFF
      def catLFFs(output, outputDir, trackLFFs, filesToCleanUp)
        allInputLFFname = "#{output}.allTracks.lff"
        cleanInputLFF = allInputLFFname.gsub(/ /, '\ ') # Need this for Bash-type commands (but not for most BRL Ruby tools)
        trackLFFsStr = trackLFFs.join(' ')
        cmdStr = "cat #{trackLFFsStr} > #{cleanInputLFF}"
        $stderr.puts "\nANNO SELECTOR: concat command for all input tracks:\n\n#{cmdStr}\n\n"
        cmdOk = system(cmdStr)
        unless(cmdOk)
          raise "\n\nERROR: LffSelectorClass#catLFFs => error with calling lff file cat.\n" +
                  "    - exit code: #{$?}\n" +
                  "    - command:   #{cmdStr}\n"
        else
          filesToCleanUp << allInputLFFname
        end
        return allInputLFFname
      end

      # ---------------------------------------------------------------
      # TOOL-EXECUTION METHOD
      # - THIS IS THE FUNCTION THAT RUNS THE ACTUAL TOOL.
      # - Must match the top-level hash key in self.functions() above.
      # ---------------------------------------------------------------
      # - Here, it is called 'tileLongAnnos', as returned by self.functions()
      # - Argument must be 'options', a hash with form data and a couple extra
      #   entries added by the framework. Get your data from there.
      # - NOTE: It is also possible to *do* the actual tool here. That might not
      #   be a good idea, for organization purposes. Keep the tool *clean* of this
      #   framework/convention stuff and make it it's own class or even program.
      def selectAnnos( options )
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
        # File path where input data is and where output goes:
        output = options[:output]

        # Selection options
        rulesJson = options[:rulesJson]
        allAny = options[:allAny]

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
        #       we must escape it (it is a very popular *normal* character and should be supported
        #       for the user as much as possible!).
        cleanOutput = output.gsub(/ /, '\ ') # you need to use this to deal with spaces in files (which are ok!)

        # Make rules file
        rulesFile = self.makeRulesFile(allAny, rulesJson, output, filesToCleanUp)

        # Make track list
        # Add track list as something sensible for display for PARAMS
        # Add trackList as a sensible string to options for display to user and then save options.
        # Make trackList for track orders
        trackList = self.makeTrackList(options)
        if(trackList.empty?)
          errMsg = "\n\nNo tracks to process.\n\n"
          $stderr.puts "ANNO SELECTOR ERROR: Anno Selector has no input tracks."
          options.each_key { |kk|
            $stderr.puts " - #{kk.inspect} => #{options[kk].inspect}"
          }
          raise errMsg
        end
        # Create a string to save in PARAMs file for display to user
        trackListStr = ''
        tcount = 0
        trackList.each { |track| trackListStr += "#{tcount+=1}. #{track}\n" }
        options[:trackList] = trackListStr

        # -------------------------------------------------------------
        # SAVE PARAM DATA (marshalled ruby)
        # -------------------------------------------------------------
        BRL::Genboree::ToolPlugins::Util::saveParamData(options, output, LffSelectorClass.functions()[:selectAnnos][:input])

        # -------------------------------------------------------------
        # PREPARATION CODE:
        # - Prepare data prior to running your tool
        # - Eg, PREPROCESS the input lff file if needed (eg to make a new file more appropriate
        #   as input for the wrapped tool or whatever). This is not always necessary.
        #
        # Some example activities follow:

        ## PRE-PAD LFF RECORDS:
        # if( needToPreprocess )  # <-- sometimes decision is based on form data.
        #   newInputLffFileName = template_lff + ".newPad"
        #   writer = BRL::Util::TextWriter.new(newInputLffFileName)
        #   reader = BRL::Util::TextReader.new(template_lff)
        #   reader.each { |line|
        #     next if(line =~ /^\s*$/ or line =~ /^\s*\[/)
        #     arrSplit = line.split("\t")
        #     next unless(arrSplit.length >= 10)
        #     # Do something to LFF line:
        #     arrSplit[5] = arrSplit[5].to_i - upstreamPadding
        #     arrSplit[6] = arrSplit[6].to_i + downstreamPadding
        #     writer.print(arrSplit.join("\t"))
        #  }
        #  writer.close()
        #  # Replace old LFF file with this new one.
        #  File.delete(template_lff)
        #  File.rename(newTemplateLff, template_lff)
        # end

        ## GET ANY DNA SEQUENCE file the tool may need also.
        # This is not always necessary.
        # Here is a sort of template / example.
        #
        # rtrv = BRL::Genboree::ToolPlugins::Util::MySeqRetriever.new()
        # fastaWriter = BRL::Util::TextWriter.new(template_lff + ".fasta")
        # lffReader = BRL::Util::TextReader.new(template_lff)
        # filesToCleanUp << template_lff  # CLEAN UP: input LFF file
        # seqRec = nil # declare in outer scope for > speed
        # # go through each sequence the Retriever finds using the lffFile:
        # rtrv.each_seq(refSeqId, lffReader) { |seqRec|
        #   # Do something with the sequence (eg write it to a command file or just a fasta file or whatever)
        #   writer.puts seqRec
        # }
        # reader.close()
        # writer.close()

        ## CREATE ANY OTHER FILES you need. For example, files with commands or
        # lists of things in tool-specific formates, etc.
        # Here is a sort of template / example:
        #
        #  p3cmdFileName = "#{output}.p3cmd"
        #  p3cmdWriter = BRL::Util::TextWriter.new(p3cmdFileName)
        #  filesToCleanUp << p3cmdFileName # CLEAN UP: primer3 execution file
        #  # write stuff to the file
        #  p3cmdWriter.puts "<some info>"
        #  p3cmdWriter.close()

        # Get LFF data

        ## SORT INPUT FILE
        ## - this preparation step is needed for *some* tiling scenarios (ok, most)
        #if(uniqAnnoNames)
        #  # Prep command string
        #  # NOTE: use ESCaped version cleanOutput, because this is a shell-call.
        #  sortCmd = "#{RUBY_APP} #{LFF_SORTER_APP} -f #{template_lff} > #{cleanOutput}.sorted 2> #{cleanOutput}.sortError "
        #  $stderr.puts "#{Time.now} TilerTool#tileLongAnnos(): SORT command is:\n    #{sortCmd}\n" # for logging
        #  # Run command
        #  cmdOK = system( sortCmd )
        #  # Record clean up files
        #  filesToCleanUp << "#{cleanOutput}.sortError"
        #  # Check command status, raise error about any problems
        #  if(cmdOK)
        #    filesToCleanUp << template_lff
        #  else
        #    errMsg = "\n\nThe Tiler program failed and did not fully complete. Error sorting the input data.\n\n"
        #    $stderr.puts  "TILER ERROR: Tiler died during sorting: '#{errMsg.strip}'\n"
        #    options.keys.sort.each { |key| $stderr.puts "  - #{key} = #{options[key]}\n" }
        #    raise errMsg
        #  end
        #else # no matter what, rename file to ".sorted" so extension is standard for all scenarios
        #  # Run command; use ESCaped version cleanOutput, because this is a shell-call.
        #  `mv #{template_lff} #{cleanOutput}.sorted`
        #end
        ## Common extension even if not actually sorted:
        #template_lff = "#{cleanOutput}.sorted"
        #filesToCleanUp << "#{template_lff}"

        # GET ANY DNA SEQUENCE file the tool may need also.
        # - This is not always necessary.

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
        # Concat all the track files into one file for convenience of lffRuleSelector.rb
        inputTrackLFF = self.catLFFs(output, outputDir, trackLFFs, filesToCleanUp)

        # -------------------------------------------------------------
        # EXECUTE WRAPPED TOOL
        # -------------------------------------------------------------
        # Prep command string:
        # - use ESCaped version cleanOutput, because this is a shell-call.
        selectorCmd = "#{RUBY_APP} #{LFF_SELECTOR_APP} " +
                      " -f '#{inputTrackLFF}' -r '#{rulesFile}' " +
                      " -c '#{CGI.escape(outputTrackClass)}' -t '#{CGI.escape(outputTrackType)}' -u '#{CGI.escape(outputTrackSubtype)}' " +
                      " -V " +
                      " > #{cleanOutput}.selected.lff 2> #{cleanOutput}.lffSelector.err"
        $stderr.puts "#{Time.now.to_s} LffSelectorTool#tileLongAnnos(): SELECTOR command is:\n    #{selectorCmd}\n" # for logging

        # Run tool command:
        cmdOK = system( selectorCmd )
        # NOTE: use ESCaped version cleanOutput, because clean up is a shell-call.
        filesToCleanUp << "#{cleanOutput}.lffSelector.err"  # CLEAN UP: err file from lffRuleSelector.

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
          filesToCleanUp << "#{cleanOutput}.selected.lff"

          # -------------------------------------------------------------
          # - UPLOAD DATA into Genboree as LFF.
          #   Sometimes the user chooses to do this or not. Sometimes it is a
          #   required step for the tool. Sometimes there is one file to upload.
          #   Sometimes there are many. Deal with the decisions and then the
          #   uploading in the following *standardized* way:
          uploadLff = "#{cleanOutput}.selected.lff".gsub(/\\ /, ' ')
          BRL::Genboree::ToolPlugins::Util::SeqUploader.uploadLFF( uploadLff, refSeqId, userId )
        else # Command failed
          # Open any files you need to in order to get informative errors or any
          # data that is available.
          # Then:
          #
          # Raise error for framework to handle, with this error.
          errMsg = "\n\nThe Anno Selector program failed and did not fully complete.\n\n"
          $stderr.puts  "SELECTOR ERROR: Selector died: '#{errMsg.strip}'\n"
          options.keys.sort.each { |key| $stderr.puts "  - #{key} = #{options[key]}\n" }
          raise errMsg
        end

        # -------------------------------------------------------------
        # CLEAN UP CALL. This is *standardized*, call it at the end.
        # -------------------------------------------------------------
        cleanup_files(filesToCleanUp) # Gzips files listed
        return [ ]
      end
    end # class TilerClass
  end # module TilerTool
end ; end ; end ; end # end namespace
