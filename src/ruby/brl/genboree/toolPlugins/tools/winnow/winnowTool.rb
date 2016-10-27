# ##############################################################################
# LIBRARIES
# ##############################################################################
require 'brl/genboree/toolPlugins/tools/winnow/winnow'
require 'brl/genboree/toolPlugins/util/util'
require 'brl/genboree/toolPlugins/util/binaryFeatures'
require 'brl/genboree/toolPlugins/util/graph'
require 'erb'
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
module BRL ; module Genboree ;  module ToolPlugins ;  module Tools
    #-------------------------------------------------------------------
    # Winnow. A supervised learning algorithm.
    #-------------------------------------------------------------------
    module WinnowTool    # module namespace to hold various classes (or even various tools)

      # ##############################################################################
      # TOOL WRAPPER
      # - a specific class with some required methods
      # - this class wraps the tool execution and is 'registered' with the framework
      # ##############################################################################
      class WinnowClass
        # ---------------------------------------------------------------
        # REQUIRED METHODS
        # ---------------------------------------------------------------
        # DEFINE your about() method
        def self.about()
            { :title=>'Winnow', :desc=>"A supervised learning algorithm.", :functions=>self.functions() }
        end

        #---------------------------------------------------------------
        # DEFINE functions(), an info-providing method.
        # - describes the characteristics of the function (tool) available
        # - keys in the returned hash must match a method name in this class.
        # - :input info key contains the custom parameters (inputs) to the tool.
        # - many other info keys, such as expname, refSeqId, etc, are universal
        #   and must be present
        #---------------------------------------------------------------
        def self.functions()
          avail = BinaryFeatures.functions.keys
          return  {
                    :winnowClassify =>
                    {
                      :title=>"Investigate Via Winnow",
                      :desc=>"Construct a model of the data by traiing the Winnow algorithm using several different thresholds",
                      :tracks=>5,
                      :displayName => '5) Winnow classifier',    # Displayed in tool-list HTML to user
                      :internalName => 'winnow',                 # Internal reference/key
                      # List all src file extensions => dest file extensions:
                      :autoLinkExtensions => { 'out.gz' => 'out.gz' },
                      # List all output extensions that will be available to the user:
                      # - NOTE: the BASE of these files is expected to be the JOB NAME provided by the user.
                      # - it is an *extension*, so a . will join it to the file BASE
                      # - make sure to adhere to this convention.
                      :resultFileExtensions =>  {
                                                  'roc_curve.png.out.gz' => true,
                                                  'results.out.gz' => true,
                                                  'model.out.gz' => true,
                                                  'feature.out.gz' => true
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
                        :trueClass_lff =>{ :desc=>"The track containing the positive samples for use in training.", :paramDisplay => -1 },
                        :falseClass_lff =>{ :desc=>"The track containing the negative samples for use in training.", :paramDisplay => -1 },
                        :binaryOption =>{
                          :desc =>"The type of binary representation for the sequence.  Currently available: #{avail.join(",")}. Different binary representations may require different inputs.  For details do a --binary-list.",
                          :extras =>BinaryFeatures.functions # When specifying binary, we have to supply extra parameters depending which binary option is chosen
                        },
                        :kmerSize =>{ :desc=>"The kmer size for binary representation.", :paramDisplay => 2 },
                        :cvFold => { :desc=> "The number of fold for cross validation", :paramDisplay => 3 },
                        :existModel =>{ :desc=>"The previously constructed model to be applied on classifying new samples.", :paramDisplay => 4 }
                      }
                    }
                  }
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
        def winnowClassify( options )
          expname= options[:expname]
          refSeqId=options[:refSeqId]
          userId = options[:userId]
          trueClass_lff=options[:trueClass_lff]
          falseClass_lff= options[:falseClass_lff]
          binaryOption= options[:binaryOption]
          kmerSize=options[:kmerSize]
          cvFold=options[:cvFold]
          existModel=options[:existModel]

          output =~ /^(.+)\/[^\/]*$/
          outputDir = $1
          checkOutputDir( outputDir ) # Make sure our target output dir exists

          #output = options[:output]
          cleanOutput = output.gsub(/ /, '\ ') # you need to use this to deal with spaces in files (which are ok!)
          # -------------------------------------------------------------
          # SAVE PARAM DATA (marshalled ruby)
          # -------------------------------------------------------------
          BRL::Genboree::ToolPlugins::Util::saveParamData(options, output, WinnowClass.functions()[:winnowClassify][:input])

          # -------------------------------------------------------------
          # EXECUTE WRAPPED TOOL
          # -------------------------------------------------------------
          # Prep command string:
          # - use ESCaped version cleanOutput, because this is a shell-call.
          winnowCmd = "#{RUBY_APP} #{WINNOW_APP} -t #{trueClass_lff} -f #{falseClass_lff} " +
                      " -b #{binaryOption} -k #{kmerSize}  -v  #{cvFold} #{' -m ' if(existModel)} " +
                      " > #{cleanOutput}.winnow.out 2> #{cleanOutput}.winnow.err"
          $stderr.puts "#{Time.now.to_s} WinnowTool#winnowClassify(): Winnow command is:\n    #{winnowCmd}\n" # for logging

          # Run tool command:
          cmdOK = system( winnowCmd )
          # NOTE: use ESCaped version cleanOutput, because clean up is a shell-call.
          filesToCleanUp << "#{cleanOutput}.winnow.out"  # CLEAN UP: out file from lffTiler.
          filesToCleanUp << "#{cleanOutput}.winnow.err"  # CLEAN UP: err file from lffTiler.

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
            filesToCleanUp << "#{trueClass_lff}_vs_#{falseClass_lff}_Winnow.roc_curve.png.out"
            filesToCleanUp << "#{trueClass_lff}_vs_#{falseClass_lff}_Winnow.results.out"
            filesToCleanUp << "#{trueClass_lff}_vs_#{falseClass_lff}_Winnow.feature.out"
            filesToCleanUp << "#{trueClass_lff}_vs_#{falseClass_lff}_Winnow.model.out"

            # -------------------------------------------------------------
            # - UPLOAD DATA into Genboree as LFF.
            #   Sometimes the user chooses to do this or not. Sometimes it is a
            #   required step for the tool. Sometimes there is one file to upload.
            #   Sometimes there are many. Deal with the decisions and then the
            #   uploading in the following *standardized* way:
            #template_lff = template_lff.gsub(/\\ /, ' ')
            #BRL::Genboree::ToolPlugins::Util::SeqUploader.uploadLFF( "#{template_lff}.tiles.lff", refSeqId, userId )
          else # Command failed
            # Open any files you need to in order to get informative errors or any
            # data that is available.
            # Then:
            #
            # Raise error for framework to handle, with this error.
            errMsg = "\n\nThe Winnow program failed and did not fully complete.\n\n"
            $stderr.puts  "WINNOW ERROR: winnow died: '#{errMsg.strip}'\n"
            options.keys.sort.each { |key| $stderr.puts "  - #{key} = #{options[key]}\n" }
            raise errMsg
          end

          # -------------------------------------------------------------
          # CLEAN UP CALL. This is *standardized*, call it at the end.
          # -------------------------------------------------------------
          cleanup_files(filesToCleanUp) # Gzips files listed
          return [ ]
        end #winnowClassify
      end # class WinnowClass
  end # module WinnowTool
end ; end ; end ; end # end namespace
