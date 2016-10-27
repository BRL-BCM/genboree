#!/usr/bin/env ruby
require 'uri'
require 'json'
require 'brl/util/util'
require 'brl/util/emailer'
require 'brl/genboree/tools/toolWrapper'
require 'brl/genboree/tools/wrapperEmailer'
require 'brl/genboree/helpers/dataImport'
require 'brl/genboree/helpers/expander'
require 'brl/util/convertText'
require 'brl/genboree/tools/scripts/uploadTrackAnnos/uploadTrackAnnosWrapper'
require 'brl/genboree/abstract/resources/user'
require 'brl/genboree/rest/apiCaller'
require "brl/genboree/helpers/sniffer"
include BRL::Genboree::REST

module BRL; module Genboree; module Tools; module Scripts
  class IndexBwaWrapper < BRL::Genboree::Tools::ToolWrapper
    VERSION = "1.0"
    COMMAND_LINE_ARGS = { }
    DESC_AND_EXAMPLES = {
      :description  => "This is the wrapper to generate BWA indices.
                        This tool is intended to be called via the Genboree Workbench or internally by other tools.",
      :authors      => [ "Neethu Shah (neethus@bcm.edu)" ],
      :examples     => [
        "#{File.basename(__FILE__)} --inputFile=filePath",
        "#{File.basename(__FILE__)} -j filePath",
        "#{File.basename(__FILE__)} --help"
      ]
    }
    attr_accessor :exitCode
    # Extract the relevant information to run the job
    # [+returns+] nil
    def processJobConf()
      begin
        dbrcFile = File.expand_path(ENV['DBRC_FILE'])
        
        ## Genboree specific "context" variables
        @dbrcKey = @context['apiDbrcKey']
        @adminEmail = @context['gbAdminEmail']
        @userId = @context['userId']
        @jobId = @context['jobId']
        @jobId = 0 unless @jobId
        @userEmail = @context['userEmail']
        @userLogin = @context['userLogin']
        @userFirstName = @context['userFirstName']
        @userLastName = @context['userLastName']
        dbrc = BRL::DB::DBRC.new(dbrcFile, @dbrcKey)
        @user = dbrc.user
        @pass = dbrc.password
        @host = dbrc.driver.split(/:/).last
        @scratchDir = @context['scratchDir']
        @scratchDir = "." if(@scratchDir.nil? or @scratchDir.empty?)
        
        ## Check if output is written locally in a directory or copied to Genboree db
        @outputLocally = (@outputs[0] =~ /^\// ? true : false )
        
        if(@outputLocally)
          @resultsDir = File.expand_path(@outputs[0])
          @groupName = "Internal BWA Indexing"
          @dbName = "Internal BWA Indexing"
        else
          @targetUri = @outputs[0]
          @groupName = @grpApiHelper.extractName(@outputs[0])
          @dbName = @dbApiHelper.extractName(@outputs[0])
        end
        
        @genomeVersion = @settings['genomeVersion']
        @epList = @settings['epList']
 
        @indexBaseName = @settings['indexBaseName'] 
        if(!@indexBaseName)
          @indexBaseName = @genomeVersion.dup
        end
        @epFile = "#{@scratchDir}/#{CGI.escape(@indexBaseName)}_custom.fa"
        @outputIndexFile = "#{CGI.escape(@indexBaseName)}.tar.gz" 

        ## If wrapper is called internally from another tool, 
        ## then suppress emails
        @suppressEmail = (@settings["suppressEmail"].to_s.strip =~ /^(?:true|yes)$/i ? true : false)
           
      rescue => err
        @errUserMsg = "ERROR: Could not set up required variables for running job. "
        @errInternalMsg = "ERROR: Could not set up required variables for running job. Check your jobFile.json to make sure all variables are defined."
        @err = err.backtrace.join("\n")
        @exitCode = 22
      end
      return @exitCode
    end

    # Runs the script
    # [+returns+] nil
    def run()
      begin
        # Get data
        @user = @pass = nil
        @outFile = @errFile = ""
        @hostAuthMap = Abstraction::User.getHostAuthMapForUserId(nil, @userId)
        if(@dbrcKey)
          dbrc = BRL::DB::DBRC.new(@dbrcFile, @dbrcKey)
          # get super user, pass and hostname
          @user = dbrc.user
          @pass = dbrc.password
        else
          suDbDbrc = BRL::Genboree::GenboreeUtil.getSuperuserDbrc(@genbConf, @dbrcFile)
          @user = suDbDbrc.user
          @pass = suDbDbrc.password
        end
          
        # Create bwa index for reference sequences in user db
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Bwa Index not available anywhere, making it now.")
        makeBwaIndex()
     
        # Compress index files
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Compressing index files to make #{@outputIndexFile}.")
        `cd #{@scratchDir}; tar czf #{@outputIndexFile} #{CGI.escape(@indexBaseName)}.*`
          
        if(@outputLocally)
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Moving index files to results dir")
          system("mv #{@scratchDir}/#{@outputIndexFile} #{@resultsDir}/")
          `touch #{@scratchDir}/internalBwaIndexingJob.txt`
        else
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Transferring index files to user db")
          transferFiles()
          # Remove FASTA file
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Removing reference FASTA seq file")
          `rm -f #{@epFile}`
        end

      rescue => err
        @err = err
        # Try to read the out file first:
        outStream = ""
        outStream << File.read(@outFile) if(File.exists?(@outFile))
        # If out file is not there or empty, read the err file
        if(!outStream.empty?)
          errStream = ""
          errStream = File.read(@errFile) if(File.exists?(@errFile))
          @errUserMsg = errStream if(!errStream.empty?)
        end
        @exitCode = 30
      end
      return @exitCode
    end

#### Methods used in this wrapper

    ## Make bwa  index for user uploaded reference sequences
    def makeBwaIndex()  
      @outFile = "#{@scratchDir}/indexBwa.out"
      @errFile = "#{@scratchDir}/indexBwa.err"

      ## Get entrypoint sequences in FASTA format
      getFasta()  

      ## Build Bwa index
      command = "bwa index -p #{@scratchDir}/#{CGI.escape(@indexBaseName)}"
      if(File.size(@epFile) < 1800000000)
        command << " -a is"
      else
        command << " -a bwtsw"
      end 
      command << " #{@epFile} > #{@outFile} 2> #{@errFile}"  
      @bwaIndexDir = @scratchDir
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Launching command: #{command}")
      exitStatus = system(command)
      if(!exitStatus)
        @errUserMsg = "Bwa indexing failed to run"
        raise "Command: #{command} died. Check #{@outFile} and #{@errFile} for more information."
      end
    end

    ## Get reference sequences of entrypoints in FASTA format and write
    # to outputFile. 
    def getFasta()
      outputUri = URI.parse(@outputs[0])
      if(@epList)
        rsrcPath = "#{outputUri.path}/eps?format=fasta&epList=#{@epList}"
      else
        rsrcPath = "#{outputUri.path}/eps?format=fasta"
      end
      apiCaller = ApiCaller.new(outputUri.host, rsrcPath, @hostAuthMap)
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Getting entry points from user db")
      File.open(@epFile, 'w') {|writeIndexFile|
        apiCaller.get() { |chunk| writeIndexFile.write(chunk) }
      }
      if(!apiCaller.succeeded?)
        @errUserMsg = "Failed to get entrypoints in FASTA format from db"
        raise "ApiCaller Failed: #{apiCaller.respBody.inspect}"
      end
    end

    ## Transfer outputs to user database
    def transferFiles()
      targetUri = URI.parse(@outputs[0])
      rsrcPath = "#{targetUri.path}/file/indexFiles/BWA/{indexBase}/{outputFile}/data?"
      rsrcPath << "gbKey=#{@dbApiHelper.extractGbKey(@outputs[0])}" if(@dbApiHelper.extractGbKey(@outputs[0]))
      
      apiCaller = ApiCaller.new(targetUri.host, rsrcPath, @hostAuthMap)
      apiCaller.put({:indexBase => @indexBaseName, :outputFile => @outputIndexFile}, File.open("#{@scratchDir}/#{@outputIndexFile}"))
    end
    
###################################################################################

    def prepSuccessEmail()
      additionalInfo = ""
      additionalInfo << "  Database: '#{@dbName}'\n  Group: '#{@groupName}'\n\n" +
                        "You can download index file from 'indexFiles/BWA/#{@indexBaseName}' folder under 'Files'.\n\n\n"
      successEmailObject = BRL::Genboree::Tools::WrapperEmailer.new(@toolTitle, @userEmail, @jobId, @userFirstName, @userLastName, analysisName="", inputsText="n/a", outputsText="n/a", settings=nil, additionalInfo, resultFileLocations=nil, resultFileURLs=nil, @shortToolTitle)
      if(@suppressEmail)
        return nil
      else
        return successEmailObject
      end
    end

    def prepErrorEmail()
      additionalInfo = @errUserMsg
      errorEmailObject = BRL::Genboree::Tools::WrapperEmailer.new(@toolTitle, @userEmail, @jobId, @userFirstName, @userLastName, analysisName="", inputsText="n/a", outputsText="n/a", settings=nil, additionalInfo, resultFileLocations=nil, resultFileURLs=nil, @shortToolTitle)
      if(@suppressEmail)
        return nil
      else
        return errorEmailObject
      end
    end
  end
end; end ; end ; end

# IF we are running this file (and not using it as a library), run it:
if($0 and File.exist?($0) and BRL::Script::runningThisFile?($0, __FILE__, true))
  # Argument to main() is your specific class:
  BRL::Genboree::Tools::main(BRL::Genboree::Tools::Scripts::IndexBwaWrapper)
end
