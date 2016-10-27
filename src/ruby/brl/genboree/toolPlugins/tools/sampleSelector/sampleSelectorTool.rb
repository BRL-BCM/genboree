# ##############################################################################
# LIBRARIES
# ##############################################################################
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
  module SampleSelectorTool    # module namespace to hold various classes (or even various tools)

  # ##############################################################################
  # TOOL WRAPPER
  # - a specific class with some required methods
  # - this class wraps the tool execution and is 'registered' with the framework
  # ##############################################################################
    class SampleSelectorClass  # an actual tool

      # ---------------------------------------------------------------
      # REQUIRED METHODS
      # ---------------------------------------------------------------
      # DEFINE your about() method
      def self.about()
        return  {
                  :title => funcs[:selectSamples][:title],
                  :desc => funcs[:selectSamples][:desc],
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
          :selectSamples =>     # Must match a method name in this class (tool execution method)
          {
            :title => 'Select Samples',
            :desc => 'Selects samples according to user-provided criteria.',
            :displayName => '9) Sample Selector', # Displayed in tool-list HTML to user
            :internalName => 'sampleSelector',           # Internal reference/key
            # List all src file extensions => dest file extensions:
            :autoLinkExtensions => { 'txt.gz' => 'txt.gz' },
            # List all output extensions that will be available to the user:
            # - NOTE: the BASE of these files is expected to be the JOB NAME provided by the user.
            # - it is an *extension*, so a . will join it to the file BASE
            # - make sure to adhere to this convention.
            :resultFileExtensions =>  {
                                        'selected.txt.gz' => true,
                                        'rules.yaml.gz' => true,
                                      },
            # :INPUT parameters
            # - These *must* match the form element ids EXACTLY.
            # - Form element data is pre-processed a bit before you get it.
            # - They CANNOT be missing in the form nor missing here, unless noted.
            :input =>
            {
              # Standard: job name and database id
              :expname  =>  { :desc => "Job Name: ", :paramDisplay => 1 },
              :refSeqId => { :desc => "Genboree uploadId for input sample data: ", :paramDisplay => -1 },
              :userId => { :desc => "Genboree userId for submitting user:", :paramDisplay => -1  },
              # Tool-specific parameters:
              # - NONE
              # Output track parameters:
              # - NONE
            }
          }
        }
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

      # Make sample file to be processed
      def makeSampleFile(outputDir, refSeqId, userId, filesToCleanUp)
        # Get the dbrc key we are supposed to use on this machine
        genbConf = BRL::Genboree::GenboreeConfig.new()
        genbConf.loadConfigFile()
        dbrcFile = genbConf.dbrcFile
        dbrcKey = genbConf.dbrcKey
        # Put the sample file in the actual tool execution directory. Much more convenient and localized.
        sFileName = "#{outputDir}/samples-#{Time.now.to_i}-#{rand(65535)}.txt"
        commandStr = "sampleDownloader.rb " +
                     " -s #{dbrcKey} " +
                     " -r #{dbrcFile} " +
                     " -d #{refSeqId} " +
                     " -V " +
                     " > #{sFileName} " +
                     " 2> #{sFileName}.err "
        $stderr.puts "#{Time.now.to_s} SAMPLE SELECTOR: sample-download command:\n\n#{commandStr}\n\n"
        cmdOk = system(commandStr)
        unless(cmdOk)
          raise "\n\nERROR: SampleSelectorClass#makeSampleFile => error with calling sample downloader.\n" +
                "    - exit code: #{$?.exitstatus}\n" +
                "    - command:   #{commandStr}\n"
        else
          filesToCleanUp << sFileName
          filesToCleanUp << "#{sFileName}.err"
        end
        return sFileName
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
      def selectSamples( options )
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
        # - NONE

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

        # -------------------------------------------------------------
        # SAVE PARAM DATA (marshalled ruby)
        # -------------------------------------------------------------
        BRL::Genboree::ToolPlugins::Util::saveParamData(options, output, SampleSelectorClass.functions()[:selectSamples][:input])

        # -------------------------------------------------------------
        # PREPARATION CODE:
        # - Prepare data prior to running your tool
        # - Eg, PREPROCESS the input lff file if needed (eg to make a new file more appropriate
        #   as input for the wrapped tool or whatever). This is not always necessary.

        # GET ANY DNA SEQUENCE file the tool may need also.
        # - This is not always necessary.

        # DUMP SAMPLE FILE FOR database
        sFileName = self.makeSampleFile(outputDir, refSeqId, userId, filesToCleanUp)
        unless(File.size?(sFileName))
          errMsg = "\n\nNo samples to process.\n\n"
          $stderr.puts "\n\nSAMPLE SELECTOR ERROR: Sample Selector has no samples to process. (Sample file: #{sFileName.inspect})"
          options.each_key { |kk|
            $stderr.puts " - #{kk} => #{options[kk].inspect}"
          }
          raise errMsg
        end

        # -------------------------------------------------------------
        # EXECUTE WRAPPED TOOL
        # -------------------------------------------------------------
        # Prep command string:
        # - use ESCaped version cleanOutput, because this is a shell-call.
        selectorCmd = "sampleRuleSelector.rb " +
                      " -f '#{sFileName}' -r '#{rulesFile}' " +
                      " -V " +
                      " > #{cleanOutput}.selected.txt 2> #{cleanOutput}.sampleSelector.err"
        $stderr.puts "#{Time.now.to_s} SampleSelectorTool#selectSamples(): SELECTOR command is:\n\n#{selectorCmd}\n" # for logging

        # Run tool command:
        cmdOK = system( selectorCmd )
        # NOTE: use ESCaped version cleanOutput, because clean up is a shell-call.
        filesToCleanUp << "#{cleanOutput}.sampleSelector.err"  # CLEAN UP: err file from lffRuleSelector.

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
          filesToCleanUp << "#{cleanOutput}.selected.txt"

          # -------------------------------------------------------------
          # - UPLOAD DATA into Genboree as LFF.
          #   Sometimes the user chooses to do this or not. Sometimes it is a
          #   required step for the tool. Sometimes there is one file to upload.
          #   Sometimes there are many. Deal with the decisions and then the
          #   uploading in the following *standardized* way:
          # - N/A
        else # Command failed
          # Open any files you need to in order to get informative errors or any
          # data that is available.
          # Then:
          #
          # Raise error for framework to handle, with this error.
          errMsg = "\n\nThe Sample Selector program failed and did not fully complete.\n\n"
          $stderr.puts  "SAMPLE SELECTOR ERROR: Selector died: '#{errMsg.strip}'\n"
          options.keys.sort.each { |key| $stderr.puts "  - #{key} = #{options[key]}\n" }
          raise errMsg
        end

        # -------------------------------------------------------------
        # CLEAN UP CALL. This is *standardized*, call it at the end.
        # -------------------------------------------------------------
        cleanup_files(filesToCleanUp) # Gzips files listed
        return [ ]
      end
    end # class SampleSelectorClass
  end # module SampleSelectorTool
end ; end ; end ; end # end namespace
