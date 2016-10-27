# ##############################################################################
# LIBRARIES
# ##############################################################################
require 'erb'
require 'yaml'
require 'cgi'
require 'uri'
require 'json'
require 'brl/util/textFileUtil'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/toolPlugins/util/util.rb'
require 'brl/cluster/clusterJob'
require 'brl/cluster/clusterJobManager'
require 'brl/genboree/lockFiles/genericDbLockFile'
require 'brl/genboree/rest/apiCaller'
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
  module AttributeLifterTool    # module namespace to hold various classes (or even various tools)

  # ##############################################################################
  # TOOL WRAPPER
  # - a specific class with some required methods
  # - this class wraps the tool execution and is 'registered' with the framework
  # ##############################################################################
    class AttributeLifterClass  # an actual tool
      
      
      def self.runsOnCluster?
        genbConf = BRL::Genboree::GenboreeConfig.load
        useClusterForAttributeLifter = genbConf.useClusterForAttributeLifter                
        #Are we supposed to use the cluster for this plugin?
        if( useClusterForAttributeLifter == "true" or useClusterForAttributeLifter == "yes" )  then
          return true
        else
          return false
        end
      end
      
      # ---------------------------------------------------------------
      # REQUIRED METHODS
      # ---------------------------------------------------------------
      # DEFINE your about() method
      def self.about()
        return  {
                  :title => 'Attribute Lifter',
                  :desc => 'Copies attribute from annotations on 1+ tracks to annotation on another track.',
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
          :liftAttributes =>     # Must match a method name in this class (tool execution method)
          {
            :title => 'Attribute Lifter',
            :desc => 'Copies attributes from annotations on 1+ tracks to annotations on another track.',
            :displayName => '6) Attribute Lifter',     # Displayed in tool-list HTML to user
            :internalName => 'attributeLifter',             # Internal reference/key
            # List all src file extensions => dest file extensions:
            :autoLinkExtensions => { 'attrsLifted.lff.gz' => 'attrsLifted.lff.gz' },
            # List all output extensions that will be available to the user:
            # - NOTE: the BASE of these files is expected to be the JOB NAME provided by the user.
            # - it is an *extension*, so a . will join it to the file BASE
            # - make sure to adhere to this convention.
            :resultFileExtensions =>  {
                                        'attrsLifted.lff.gz' => true,
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
              :template_lff => { :desc => "Track to add attributes to: ", :paramDisplay => -1},
              # Exception: this following is created by the framework for
              # _lff form data elements. We use this to keep the existing parameter, since framework changes any *_lff NVPs.
              :template_lff_ORIG => { :desc => "Track to add attributes to: ", :paramDisplay => 2},

              # List of tracks to use to detected LIFTER annotations.
              :secondTrackStr => { :desc => "Tracks to lift (copy) attributes from: ", :paramDisplay => -1},
              # - saved in human-readable format in the following option:
              :trackList => { :desc => "Tracks to lift (copy) attributes from: ", :paramDisplay => 3},

              # Tool-specific parameters:
              :radius => { :desc => "Radius around anno to look for annos to lift attributes from: ", :paramDisplay => 3 },
              :requireIntersect => { :desc => "Only output annotations with intersection: ", :paramDisplay => 5},

              # Output track parameters:
              :trackClass => { :desc => "Output track class: ", :paramDisplay => 12 },
              :trackType => { :desc => "Output track type: ", :paramDisplay => 13 },
              :trackSubtype => { :desc => "Output track subtype: ", :paramDisplay => 14 },
            }
          }
        }
      end

      def makeTrackLFFs(outputDir, secondTracksHash, refSeqId, userId, filesToCleanUp)
        trackLFFs = []
        # Let's put the auto-lff in the actual tool execution directory! Much more convenient and localized.
        secondTracksHash.each_key { |trackName|
          cleanTrack = CGI.escape(trackName) # Make the track ultra-safe for DIR-naming
          trackLFF = "#{outputDir}/#{userId}_#{refSeqId}_#{cleanTrack}_#{Time.now.to_i}.lff"
          commandStr = "java -classpath #{JCLASS_PATH} -Xmx1800M " +
                       " org.genboree.downloader.AnnotationDownloader " +
                       " -u #{userId} " +
                       " -r '#{refSeqId}' " +
                       " -m '#{CGI.escape(trackName)}' " +
                       " > #{trackLFF} " +
                       " 2> #{trackLFF}.err "
          $stderr.puts "\n\nLIFTER ANNOS DETECTOR: track-download command:\n\n#{commandStr}\n\n"
          cmdOk = system(commandStr)
          unless(cmdOk)
            raise "\n\nERROR: AttributeLifterClass#makeTrackLFFs => error with calling annotation downloader.\n" +
                  "    - exit code: #{$?}\n" +
                  "    - command:   #{commandStr}\n"
          else
            trackLFFs << trackLFF
            filesToCleanUp << trackLFF
            filesToCleanUp << "#{trackLFF}.err"
          end
        }
        if(trackLFFs.empty?)
          errMsg = "\n\nNo tracks provided for lifting attribute from.\n\n"
          $stderr.puts "LIFTER ANNOS DETECTOR ERROR: No tracks provided as source of attributes to lift from."
          options.each_key { |kk|
            $stderr.puts " - #{kk} => #{options[kk].inspect}"
          }
          raise errMsg
        end
        return trackLFFs
      end
      
      

      def getTrackAttrHash(options)
        secondTrackStr = options[:secondTrackStr]
        trackAttrHash = Hash.new {|hh,kk| hh[kk] = [] }
        trackListStr = ''
        tcount = 0
        entries = secondTrackStr.split(/;/)
        entries.each { |entry|
          entry.strip!
          if(entry =~ /^([^:]+):([^:]+):([^=;]+)=([^=;]+)$/)
            type = $1
            subtype = $2
            srcAttribute = $3
            destAttribute = $4
          else
            $stderr.puts "LIFTER ANNOS DETECTOR WARNING: Bad attributes record found (#{entry})"
            next
          end
          trackAttrHash["#{type}:#{subtype}"] << "#{srcAttribute} => #{destAttribute}"
        }
        return trackAttrHash
      end

      # MAKE TRACK LIST STR
      # - this human-readable string is what will be saved in the parameter file
      def saveTrackAttributeListStr(trackAttrHash, options)
        trackListStr = ''
        trackAttrHash.each_key { |trackName|
          trackListStr << "#{trackName}\n"
          trackAttrHash[trackName].each { |attrStr|
            trackListStr << "  - #{attrStr}\n"
          }
        }
        options[:trackList] = trackListStr
        return options
      end

      # ---------------------------------------------------------------
      # TOOL-EXECUTION METHOD
      # - THIS IS THE FUNCTION THAT RUNS THE ACTUAL TOOL.
      # - Must match the top-level hash key in self.functions() above.
      # ---------------------------------------------------------------
      # - Here, it is called 'liftAttributes', as returned by self.functions()
      # - Argument must be 'options', a hash with form data and a couple extra
      #   entries added by the framework. Get your data from there.
      # - NOTE: It is also possible to *do* the actual tool here. That might not
      #   be a good idea, for organization purposes. Keep the tool *clean* of this
      #   framework/convention stuff and make it it's own class or even program.
      def liftAttributes( options )
        # Keep track of files we want to clean up (gzip) when finished
        fh = File.open("/tmp/blah","w")
        fh.puts options.keys.inspect
      
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
        groupId = options[:groupId]
        # Framework has turned this into a file-path to the LFF:
        template_lff = options[:template_lff]
        firstTrackOperand = options[:template_lff_ORIG]
        # File path where input data is and where output goes:
        output = options[:output]

        # Lifting options
        secondTrackStr = options[:secondTrackStr]
        secondTracksHash = getTrackAttrHash(options)
        radius = options[:radius].to_i
        requireIntersect = (options[:requireIntersect] == 'true')

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

        # Add trackList as a sensible string to options for display to user.
        options = saveTrackAttributeListStr(secondTracksHash, options)

        # -------------------------------------------------------------
        # SAVE PARAM DATA (marshalled ruby)
        # -------------------------------------------------------------
        BRL::Genboree::ToolPlugins::Util::saveParamData(options, output, AttributeLifterClass.functions()[:liftAttributes][:input])

        # -------------------------------------------------------------
        # PREPARATION CODE:
        # - Prepare data prior to running your tool

        # Create LFF file with data from secondary tracks in it
        clusterJob = nil
        genbConf = BRL::Genboree::GenboreeConfig.load
        useClusterForAttributeLifter = genbConf.useClusterForAttributeLifter
        trackString = ""
        
        #Are we supposed to use the cluster for this plugin?
        if( useClusterForAttributeLifter == "true" or useClusterForAttributeLifter == "yes" )  
          trackLFFs = Array.new
          
          # InputFile will be local during cluster execution. Need containing dir. to use as output dir. after cluster run
          cleanOutput = cleanOutput.gsub(/#{outputDir}/,".")
          template_lff = template_lff.gsub(/#{outputDir}/,".")          
          jobId = Time.now.to_i.to_s + "_#{rand(65525)}"
          hostname = ENV["HTTP_HOST"] || genbConf.machineName
          # Who gets notified about cluster job status changes?
          clusterAdminEmail = 'raghuram@bcm.edu'
          # hostname:outputDir is the output directory for the cluster job to move files to from the temporary working directoryon the node after it is done executing
          # Supply job name, output dir, notification email and a flag to specify whether to retain temp. working dir.                    
          clusterJob = BRL::Cluster::ClusterJob.new("job-#{jobId}", hostname.strip.to_s + ":" + outputDir, clusterAdminEmail, "false")          
          cleanTrack = CGI.escape(firstTrackOperand)
          commandStr = "java -classpath #{JCLASS_PATH} -Xmx1800M " +
                          " org.genboree.downloader.AnnotationDownloader " +
                          " -u #{userId}" +
                          " -r '#{refSeqId}' " +
                          " -m '#{cleanTrack}"
          secondTracksHash.each_key { |trackName|
            cleanTrack = CGI.escape(trackName) # Make the track ultra-safe for DIR-naming            
            commandStr += ",#{cleanTrack}"            
          }          
          commandStr += "' > #{template_lff}"
          # Suitably modified 'main' command for the cluster job to execute on the node
          clusterJob.commands << CGI.escape(commandStr)
          fh.puts(commandStr)
          trackString = CGI.escape(template_lff)
        else
          trackLFFs = self.makeTrackLFFs(outputDir, secondTracksHash, refSeqId, userId, filesToCleanUp)
          trackLFFsStr = trackLFFs.join(',')
          trackString = "#{CGI.escape(template_lff)},#{CGI.escape(trackLFFsStr)}"
        end          
          
          fh.puts template_lff          
          
        # Clean up the input file too
        filesToCleanUp << "#{template_lff}"        
        

        # -------------------------------------------------------------
        # EXECUTE WRAPPED TOOL
        # -------------------------------------------------------------
        # Prep command string:
        # - use ESCaped version cleanOutput, because this is a shell-call.
        # First, prep the secondary track args string
        secondTracksArg = CGI.escape(secondTrackStr)
        
        lifterCmd = "attributeLifter.rb -f #{CGI.escape(firstTrackOperand)} -l '#{trackString}' -o #{cleanOutput}.attrsLifted.lff " +
                    " -r #{radius} -t #{secondTracksArg} " +
                    " -c '#{CGI.escape(outputTrackClass)}' -n '#{CGI.escape(outputTrackType + ":" + outputTrackSubtype)}' "
        lifterCmd << " -p " if(requireIntersect)
        lifterCmd << " > #{cleanOutput}.attrsLifted.out 2> #{cleanOutput}.attrsLifted.err"
        filesToCleanUp << "#{cleanOutput}.attrsLifted.out"
        filesToCleanUp << "#{cleanOutput}.attrsLifted.err"
        
      
        
        if( useClusterForAttributeLifter == "true" or useClusterForAttributeLifter == "yes" )
          clusterJob.commands << CGI.escape(lifterCmd)
                    
          #Send Email that lifting is complete and upload has been spawned off
          emailSubject = "GENBOREE TOOL: Attribute Lifter job #{expname} has been run"
          emailFrom = "genboree_admin@genboree.org"
          user = BRL::Genboree::ToolPlugins.getUser( userId )
          name = "#{user[3]} #{user[4]}"          
          emailTo = user[6] # internal DB name
          emailBody = "Congratulations #{name}!\n\nYour Attribute Lifter job '#{expname}' has been run by Genboree and and has produced results."+
            "\n \nYour result file #{cleanOutput.gsub(/^\W*/,"")}.attrsLifted.lff is being uploaded to Genboree. You will receive an email when "+
            "\nthe upload is complete. You can then view your results under the experiment results section for this group. (Tools->Plugin Results)"+
            "\n\nThank you for using Genboree,"+
            "\nThe Genboree Team"
        
          # Subject From To Body
          emailerCmd = "emailer.rb -s #{CGI.escape(emailSubject)} -f #{CGI.escape(emailFrom)} -t #{CGI.escape(emailTo)} -b #{CGI.escape(emailBody)} "          
          
          clusterJob.commands << CGI.escape(emailerCmd)
          cleanFile = "#{cleanOutput}.attrsLifted.lff"
          commandStr = "java -classpath #{JCLASS_PATH} "+
              " -Xmx800M org.genboree.upload.AutoUploader " +
              " -t lff -r #{refSeqId.to_i} " +
              " -f #{cleanFile} -u #{userId} -z > #{cleanFile}.errors 2>&1 "
          # Command for uploader
          filesToCleanUpAfterUpload = []
          filesToCleanUpAfterUpload << "#{cleanFile}.errors"
          filesToCleanUpAfterUpload << "#{cleanFile}.log"
          filesToCleanUpAfterUpload << "#{cleanFile}.full.log"
          filesToCleanUpAfterUpload << "#{cleanFile}.entrypoints.lff"
          filesToCleanUpAfterUpload << "#{cleanFile}"          
          uploadCommandStr = CGI.escape(commandStr)
          filesToCleanUpAfterUpload.each{|file|  uploadCommandStr << ",#{CGI.escape("gzip #{file}")}"}
          clusterJob.commands<<CGI.escape("uploadWrapper.rb -o #{clusterJob.outputDirectory} -i ./#{cleanFile} -c #{CGI.escape(uploadCommandStr)} -p #{clusterJob.jobName}")
          filesToCleanUp.each{|file|  clusterJob.commands << CGI.escape("gzip #{file}")}
          clusterJob.resources << genbConf.clusterAttributeLifterResourceFlag+"=1"
          
          # Create a resource identifier string for this job which can be used to track resource usage
          # Format is /REST/v1/grp/{grp}/db/{db}/trk/{trk}
          dbu = BRL::Genboree::DBUtil.new(genbConf.dbrcKey,nil,nil)
          groupName = dbu.selectGroupById(groupId)[0]["groupName"]
          refSeqName = dbu.selectRefseqById(refSeqId)[0]["refseqName"]
          apiCaller = BRL::Genboree::REST::ApiCaller.new("proline.brl.bcm.tmc.edu", "/REST/v1/grp/{grp}/db/{db}/trk/{trk}")
          rsrcId = apiCaller.fillApiUriTemplate( { :grp => groupName, :db => refSeqName, :trk => outputTrackType + ":" + outputTrackSubtype } )
          uri = URI.parse(rsrcId)
          resourceIdentifier = uri.path          
          clusterJob.resourcePaths << resourceIdentifier
          fh.puts resourceIdentifier
          # Should the temporary working directory of the cluster job be retained on the node?
          if(genbConf.retainClusterAttributeLifterDir=="true" or genbConf.retainClusterAttributeLifterDir=="yes")
            clusterJob.removeDirectory = "false"
          else
            clusterJob.removeDirectory = "true"
          end
          begin
            # Get a lock in order to submit the job to the scheduler
            @dbLock = BRL::Genboree::LockFiles::GenericDbLockFile.new(:clusterJobDb)
            @dbLock.getPermission()
            clusterJobManager = BRL::Cluster::ClusterJobManager.new(genbConf.schedulerDbrcKey,genbConf.schedulerTable)
            # Put the job in the scheduler table
            schedJobId = clusterJobManager.insertJob(clusterJob)
          rescue Exception => err 
            fh.puts "#{Time.now.to_s} ERROR: Inserting job into scheduler table"
            fh.puts err.to_s
            fh.puts err.backtrace.join("\n")
          ensure
            begin
              # Release lock
              @dbLock.releasePermission() unless(@dbLock.nil?)
            rescue Exception => err1
              fh.puts "#{Time.now.to_s} ERROR: Releasing lock on lock file #{@dbLock.lockFileName}"
              fh.puts err1.to_s
              fh.puts err1.backtrace.join("\n")
            end
          end
          if(schedJobId.nil?) then
            fh.puts("#{Time.now.to_s} Error submitting job to the scheduler")
          else
            fh.puts("Your Job Id is #{schedJobId}")
          end
          
      else
        
        $stderr.puts "#{Time.now.to_s} AttributeLifter#liftAttributes(): LIFTER command is:\n    #{lifterCmd}\n" # for logging
        # Run tool command:
        cmdOK = system( lifterCmd )
        $stderr.puts "#{Time.now.to_s} AttributeLifter#liftAttributes(): LIFTER command exit ok? #{cmdOK.inspect}\n"
       
        # NOTE: use ESCaped version cleanOutput, because clean up is a shell-call.
        fh.puts lifterCmd
        fh.puts filesToCleanUp.inspect
        fh.puts cleanOutput
        fh.puts outputDir
        fh.close
        # -------------------------------------------------------------
        # CHECK RESULT OF TOOL.
        # - Eg this might be a command code ($? after a system() call), nil/non-nil,
        #   or whatever. If ok, process any raw tool output files if needed. If not ok, put error info.
        #
        #-------------------------------------------------------------
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

          # -------------------------------------------------------------
          # - UPLOAD DATA into Genboree as LFF.
          #   Sometimes the user chooses to do this or not. Sometimes it is a
          #   required step for the tool. Sometimes there is one file to upload.
          #   Sometimes there are many. Deal with the decisions and then the
          #   uploading in the following *standardized* way:
          BRL::Genboree::ToolPlugins::Util::SeqUploader.uploadLFF( "#{output}.attrsLifted.lff", refSeqId, userId )
          filesToCleanUp << "#{cleanOutput}.attrsLifted.lff"
          
        else # Command failed
          # Open any files you need to in order to get informative errors or any
          # data that is available.
          # Then:
          #
          # Raise error for framework to handle, with this error.
          errMsg = "\n\nThe LIFTER Annotation Detection program failed and did not fully complete.\n\n"
          $stderr.puts  "LIFTER ANNOS DETECTOR ERROR: attribute lifter died: '#{errMsg.strip}'\n"
          options.keys.sort.each { |key| $stderr.puts "  - #{key} = #{options[key]}\n" }
          raise errMsg
        end
       # $stderr.puts "fc #{filesToCleanup.inspect}"
        # -------------------------------------------------------------
        # CLEAN UP CALL. This is *standardized*, call it at the end.
        # -------------------------------------------------------------
        cleanup_files(filesToCleanUp) # Gzips files listed
        return [ ]
        end
      end
end # class AttributeLifterClass
  end # module AttributeLifterTool
end ; end ; end ; end # end namespace
