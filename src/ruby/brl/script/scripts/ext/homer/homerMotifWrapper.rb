#!/usr/bin/env ruby
require 'pathname'
require 'brl/util/util'
# Require scriptDriver.rb
require 'brl/script/scriptDriver'

# Write sub-class of BRL::Script::ScriptDriver
module BRL ; module Script
  # Wrapper script for certain Homer commands to workaround their unfortunate
  #   "everyone at your institution has their own homer and own homer database"
  #   design. Using a couple arguments from the user, plus a template of the
  #   Homer command they want to run, a virtual private database area is built
  #   (via softlinks to the shared existing Homer database); the Homer tools
  #   can write in this virtual database area, which most of their tools do as
  #   part of their "preprocessing" phase.
  class HomerMotifWrapper < ScriptDriver
    # ------------------------------------------------------------------
    # SUB-CLASS INTERFACE
    # - replace values for constants and implement abstract methods
    # ------------------------------------------------------------------

    # Provide the version string of this script.
    # @api ScriptDriver
    # @return [String]
    VERSION = "0.1"
    # Provide the script-specific command line argument information
    # @api ScriptDriver
    # @return [Hash{String=>Array}] {Hash} of @--longName@ arguments to {Array}
    #   of: arg type, one-char arg name, description.
    COMMAND_LINE_ARGS = {
      "--scratchDir"        =>  [ :OPTIONAL_ARGUMENT, "-s", "[Required when running Homer command]. Scratch dir where can make a personal Homer data area." ],
      "--homerDb"           =>  [ :OPTIONAL_ARGUMENT, "-g", "[Required when running Homer command]. The Homer genome name [UCSC-style] or promoter set to use for Homer analysis" ],
      "--dontCleanScratch"  =>  [ :NO_ARGUMENT, "-C", "[optional flag] Do NOT clean up the virtual Homer data scratch area created by this script. Leave dir tree and softlink mess in place in temporary area within your --scratchDir." ],
      "--listHomerDbs"      =>  [ :NO_ARGUMENT, "-l", "[optiional flag] DON'T run any Homer tool. Just output a list of available Homer DBs. (i.e. which are suitable for the --homerDB argumnent). With --verbose, provides extra info about the databases." ]

    }
    # Provide general program description, author list (you...), and 1+ example usages.
    # @api ScriptDriver
    # @return [Hash{Symbol=>Object}] with well-known {Symbols} @:description@, @:authors@, @:examples@
    DESC_AND_EXAMPLES = {
      :description => "Wraps certain Homer commands to work around the 'each-user-has-personal-Homer-install' design.\n\nMake sure to provide a Homer command template following the end-of-arguments delimiter '--'.\nThe command template looks like the actual Homer command, but has the keyword %DATA_DIR%\nin place of the target genome/promoter-set/etc.\n\n This script will build and run the Homer command by making a suitable Homer virtual data dir for you\nand filling in the %DATA_DIR% keyword (and the %HOMER_DB% if needed) appropriately in your template.\n\nThe '--verbose' option in recommended to get useful status feedback and details.",
      :authors      => [ "Andrew R Jackson (andrewj@bcm.edu)" ],
      :examples => [
        "#{File.basename(__FILE__)} --verbose --scratchDir=filePath --g human -- findMotifs.pl ./path/to/my.bed %DATA_DIR% ./path/to/outputDir ",
        "#{File.basename(__FILE__)} --scratchDir=filePath --g mm9 -- findMotifsGenome.pl ./path/to/my.bed %DATA_DIR% ./path/to/outputDir ",
        "#{File.basename(__FILE__)} --help"
      ]
    }

    # ------------------------------------------------------------------
    # NON-INTERFACE CONSTANTS
    # ------------------------------------------------------------------

    # Known Homer commands and where found in the Homer database area
    # @return [Hash{String=>Hash}]
    HOMER_CMD_CONF =
    {
      "findMotifsGenome.pl" =>
      {
        "dataSubDir" => "genomes"
      },
      "findMotifs.pl" =>
      {
        "dataSubDir" => "promoters"
      }
    }

    # ------------------------------------------------------------------
    # IMPLEMENTED INTERFACE METHODS
    # ------------------------------------------------------------------

    # @api ScriptDriver
    # @abstract
    # MUST return a numerical exitCode (20-126) and preferably set {#exitCode}. Program will
    #   exit with that code. 0 means success. Command-line args will already be parsed an
    #   checked for missing required values. {#optsHash} contains the command-line args, keyed by @--longName@
    def run()
      validateAndProcessArgs()
      if(@exitCode == EXIT_OK)
        if(@verbose)
          $stderr.puts "#{Time.now.strftime("%Y-%m-%d %H:%M:%S")} STATUS: done collecting and validating arguments. Info from env & args:"
          [ "listHomerDbs", "homerDataDir" , "homerGenomesInfoFile", "cleanScratchDir", "scratchDir", "homerDb", "commandTemplate", "homerCmd"].each { |xx|
            $stderr.puts "  - @#{xx} = #{self.instance_variable_get("@#{xx}")}"
          }
        end
        if(@listHomerDbs)
          listHomerDbs()
        else # run homer command
          homerCmdConf = HOMER_CMD_CONF[@homerCmd]
          dataSubDir = homerCmdConf["dataSubDir"]
          fullSrcDataSubDir = ( @homerCmd == 'findMotifsGenome.pl' ? "#{File.expand_path(@homerDataDir)}/#{dataSubDir}/#{@homerDb}" : "#{File.expand_path(@homerDataDir)}/promoters" )
          if(File.directory?(fullSrcDataSubDir))
            $stderr.puts "#{Time.now.strftime("%Y-%m-%d %H:%M:%S")} STATUS: the official Homer DB src dir lives here and exists: #{fullSrcDataSubDir.inspect}" if(@verbose)
            $stderr.puts "#{Time.now.strftime("%Y-%m-%d %H:%M:%S")} STATUS: about to create virtual private Homer data dir within #{@scratchDir} for the #{@homerDb} Homer DB..." if(@verbose)
            scratchDataDir = createScratchHomerDataDir(fullSrcDataSubDir)
            if(@exitCode == EXIT_OK)
              $stderr.puts "#{Time.now.strftime("%Y-%m-%d %H:%M:%S")} STATUS: ... done. The specific virtual data dir is: #{scratchDataDir.inspect}" if(@verbose)
              finalHomerCmd = buildHomerCommand(scratchDataDir)
              if(@exitCode == EXIT_OK)
                $stderr.puts "#{Time.now.strftime("%Y-%m-%d %H:%M:%S")} STATUS: thus the final Homer command to run is:\n    #{finalHomerCmd.inspect}" if(@verbose)
                `#{finalHomerCmd}`
                exitStatusObj = $?
                $stderr.puts "#{Time.now.strftime("%Y-%m-%d %H:%M:%S")} STATUS: your #{@homerCmd.inspect} run exited with status #{exitStatusObj.exitstatus} (#{exitStatusObj.success? ? "success" : "failure"})" if(@verbose)
                cleanScratchHomerDataDir()
              end
            end
          else
            @errUserMsg = "ERROR: The --homerDb argument (#{@homerDb.inspect}) is not one of the data sub-subdirs that Homer knows about. Thus the full path to the specific Homer data files is invalid (#{fullSrcDataSubDir.inspect})."
            @exitCode = 51
          end
        end
      end
      return @exitCode
    end

    # ------------------------------------------------------------------
    # SCRIPT-SPECIFIC METHODS
    # ------------------------------------------------------------------
    # - stuff needed to do actual program or drive 3rd party tools, etc
    # - repeatedly-used generic stuff is in library classes of course...

    # Extract needed info from {#optsHash} and do validations of those arguments.
    #   Sets {#exitCode} to indicate any errors/problems.
    def validateAndProcessArgs()
      # First, check env sanity
      @homerDataDir = ENV['HOMER_DATA_DIR']
      @homerGenomesInfoFile = ENV['HOMER_GENOMES_INFO']
      if(@optsHash.empty?)
        printUsage()
        @exitCode = 50
      else
        @cleanScratchDir  = @optsHash.key?('--dontCleanScratch') ? false : true
        @listHomerDbs     = @optsHash.key?('--listHomerDbs') ? true : false
        if(!@listHomerDbs)
          if(@homerDataDir and @homerGenomesInfoFile and File.directory?(@homerDataDir) and File.readable?(@homerGenomesInfoFile))
            # Next check scratch dir
            @scratchDir = @optsHash['--scratchDir']
            if(File.directory?(@scratchDir) and File.writable?(@scratchDir))
              @scratchDir = File.expand_path(@scratchDir)
              # Get homer db
              @homerDb = @optsHash['--homerDb']
              # Finally check homer command template they provided
              if(ARGV.length >= 1)
                @commandTemplate = ARGV.join(" ").strip
                @commandTemplate =~ /^(\S+)/
                @homerCmd = $1
                unless(HOMER_CMD_CONF.key?(@homerCmd))
                  @errUserMsg = "ERROR: the Homer command you supplied (#{@homerCmd.inspect}) is not one of the ones *currently* handled by this wrapper. Maybe you'd like to add support for it? Or contact someone capable, if not."
                  @exitCode = 44
                end
              else
                @errUserMsg = "ERROR: You have not provided a Homer command template following the '--' argument. Nothing to run!"
                @exitCode = 43
              end
            else
              @errUserMsg ="ERROR: Your scratch dir (#{@scratchDir.inspect}) either doesn't exist, is not a directory, or is not writable by you."
              @exitCode = 42
            end
          else
            @errUserMsg = "ERROR: Your environment doesn't seem to have valid entries for HOMER_DATA_DIR (#{@homerDataDir.inspect}) and/or HOMER_GENOMES_INFO (#{@homerGenomesInfoFile}). The shell variables must be defined and point to appropriate dir/file. Have you done the module load?"
            @exitCode = 41
          end
        end
      end
    end

    # Creates a virtual Homer database area within the scratch dir the user indicated. The
    #   virutal database area will be based on the specific shared Homer database area
    #   @srcHomerDataDir@. The virtual database dir will have a random suffix so the
    #   same scratch area can be used for multiple simultaneous Homer runs without fear
    #   of collision.
    # @param [String] srcHomerDataDir The specific shared Homer database area upon which
    #   to base the virtual database area.
    # @return [String] the path to the virutal database dir.
    def createScratchHomerDataDir(srcHomerDataDir)
      @homerTmpScratch = "#{File.expand_path(@scratchDir)}/Homer_tmp_#{@scratchDir.generateUniqueString}"
      scratchDataDir = nil
      if(@homerCmd == 'findMotifsGenome.pl')
        scratchDataDir = "#{@homerTmpScratch}/#{@homerDb}"
        `mkdir -p #{scratchDataDir}`
        # First, create dir structure
        dirs = `find #{srcHomerDataDir}/ -type d`
        dirs.each { |dir|
          dir = dir.strip
          `mkdir -p #{scratchDataDir}/#{dir.gsub(/^#{srcHomerDataDir}\//, "")}`
        }
        # Now softlink files
        files = `find #{srcHomerDataDir}/ -type f`
        files.each { |file|
          file = file.strip
          `ln -s "#{file}" "#{scratchDataDir}/#{file.gsub(/^#{srcHomerDataDir}\//, "")}"`
        }
      else
        scratchDataDir = @homerDb        
      end
      # Return the homerDb-specific sratch area that was created
      return scratchDataDir
    end

    # Builds the Homer command string to call.
    # @param [String] initializedScratchDir The virutal Homer database area to use
    #   as the target Homer database. Homer will write stuff to this area.
    # @return [String] the homer command, as it should be called.
    def buildHomerCommand(initializedScratchDir)
      homerCmd = @commandTemplate.gsub(/%DATA_DIR%/, initializedScratchDir)
      return homerCmd
    end

    # Removes the virtual Homer database area used for the run. Good idea, to save space on
    #   node scratch space, etc.
    def cleanScratchHomerDataDir()
      if(@cleanScratchDir)
        `rm -rf #{@homerTmpScratch}`
        exitStatusObj = $?
        $stderr.puts "#{Time.now.strftime("%Y-%m-%d %H:%M:%S")} STATUS: cleaned up the virtual private Homer data area. rm command exited with status #{exitStatusObj.exitstatus} (#{exitStatusObj.success? ? "success" : "failure!"})" if(@verbose)
      else
        $stderr.puts "#{Time.now.strftime("%Y-%m-%d %H:%M:%S")} STATUS: told not to clean up virtual private Homer data area. Bunch of crap left here: #{@homerTmpScratch.inspect}."
      end
    end

    # List available Homer databases (genomes, promoters, etc)
    def listHomerDbs()
      # Need to find the special configureHomer.pl script (non executable and not on path).
      # It can be found dynamically.
      aHomerCmd = `which #{HOMER_CMD_CONF.keys.first}`
      cmdDir = File.dirname(aHomerCmd)
      parentDir = File.dirname(cmdDir)
      configCmd = "perl #{parentDir}/configureHomer.pl -list 2>&1"
      configOut = `#{configCmd}`
      puts ''
      configOut.each_line { |line|
        if(@verbose)
          if(line =~ /HOMER/ or line =~ /^[A-Z\+]+/)
            puts line
          end
        else
          if(line =~ /^PROM|GENOM/)
            puts line
          elsif(line =~ /^\+\s+(\S+)/)
            db = $1
            puts "+    #{db}" unless(line =~ /^\+\s+homer/)
          end
        end
      }
      puts ''
    end
  end
end ; end # module BRL ; module Script

########################################################################
# MAIN - Provided in the scripts that implement ScriptDriver sub-classes
# - but would look exactly like this ONE LINE:
########################################################################

# IF we are running this file (and not using it as a library), run it:
if($0 and File.exist?($0) and BRL::Script::runningThisFile?($0, __FILE__, true))
  # Argument to main() is your specific class:
  BRL::Script::main(BRL::Script::HomerMotifWrapper)
end
