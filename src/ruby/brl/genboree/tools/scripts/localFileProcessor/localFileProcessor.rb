#!/usr/bin/env ruby
require 'uri'
require 'json'
require 'brl/util/util'
require 'brl/util/expander'
require 'brl/util/emailer'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/dbUtil'
require 'brl/genboree/tools/toolWrapper'
require 'brl/genboree/tools/wrapperEmailer'
require 'brl/genboree/helpers/dataImport'
require 'brl/genboree/rest/wrapperApiCaller'
require 'brl/util/convertText'
include BRL::Genboree::REST

module BRL; module Genboree; module Tools; module Scripts
  class LocalFileProcessor < BRL::Genboree::Tools::ToolWrapper
    VERSION = "1.0"
    COMMAND_LINE_ARGS = { }
    DESC_AND_EXAMPLES = {
      :description  => "This script is used for the post-processing of files that have been upload via API. The script runs as part of a 'local cluster' job and moves the uploaded file from the nginx tmp area to the final target area (workbench files). Also computes SHA1 of the uploaded file and sets some of the attributes required to 'expose' the file.",
      :authors      => [ "Sameer Paithankar(paithank@bcm.edu)" ],
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
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Getting tool specific settings...")
        @targetUri = @outputs[0]
        dbrcFile = File.expand_path(ENV['DBRC_FILE'])
        @dbrcKey = @context['apiDbrcKey']
        @adminEmail = @context['gbAdminEmail']
        @userId = @context['userId']
        @jobId = @context['jobId']
        @jobId = 0 unless @jobId
        @userEmail = @context['userEmail']
        @userLogin = @context['userLogin']
        @toolScriptPrefix = @context['toolScriptPrefix']
        @userFirstName = @context['userFirstName']
        @userLastName = @context['userLastName']
        #dbrc = BRL::DB::DBRC.new(dbrcFile, @dbrcKey)
        #@user = dbrc.user
        #@pass = dbrc.password
        #@host = dbrc.driver.split(/:/).last
        @scratchDir = @context['scratchDir']
        @scratchDir = "." if(@scratchDir.nil? or @scratchDir.empty?)
        @dbName = @settings['dbName']
        @fileId = @settings['fileId']
        @gbUploadId = @settings['gbUploadId']
        @fullFilePath = @settings['fullFilePath']
        @source = @settings['source']
        @gbUploadFalseValueId = @settings['gbUploadFalseValueId']
        @gbPartialEntityId = @settings['gbPartialEntityId']
        @extract = @settings['extract']
        @groupName = @settings['groupName']
        @refseqName = @settings['refseqName']
        @fileName = @settings['fileName']
        @doMove = @settings['doMove']
        @computeSHAAndSetAttr = @settings['computeSHAAndSetAttr']
        @suppressEmailForExtractJob = @settings['suppressEmail']
        @suppressEmail = true
      rescue => err
        @errUserMsg = "ERROR: Could not set up required variables for running job. "
        @errInternalMsg = err
        @errBacktrace = err.backtrace.join("\n")
        $stderr.debugPuts(__FILE__, __method__, "ERROR", "ERROR: #{@errUserMsg}.\nTrace:\n#{@errBacktrace}")
        @exitCode = 22
      end
      return @exitCode
    end

    # Runs the script
    # [+returns+] nil
    def run()
      begin
        # First move the file from tmp area to the final target
        if(@doMove)
          # Do some checking to make sure that file size of source file is not still 0 (because of nginx bug).
          # We do allow the job to finish eventually - in that case, the file size is probably actually 0!
          maxIterations = 10
          currentIteration = 0
          fileSizeOfSource = File.size(@source)
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "File size of source file #{@source} is #{File.size(@source)} (before any sleeping is done).")  
          while(currentIteration < maxIterations and fileSizeOfSource == 0)
            fileSizeOfSource = File.size(@source)
            $stderr.debugPuts(__FILE__, __method__, "STATUS", "File size of source file #{@source} is #{File.size(@source)} (on sleep iteration #{currentIteration+1}).")
            sleep(2)
            currentIteration += 1
          end
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Final file size of source file #{@source} is #{File.size(@source)} (after any sleeping is done).")
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Moving #{@source} to #{@fullFilePath}")
          cmd = "mv -f #{Shellwords.escape(@source)} #{Shellwords.escape(@fullFilePath)};"
          `#{cmd}` 
          exitObj = $?.dup()
          if(exitObj.exitstatus != 0)
            raise "mv command failed: #{cmd}.\n\nCommand exited with #{exitObj.inspect}"
          end
        end
        # This job is coming from databaseFileAspect
        #  - compute SHA1 and set the attributes required to 'expose' the file
        if(@computeSHAAndSetAttr)
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Starting SHA1 computation...")
          gc = BRL::Genboree::GenboreeConfig.load()
          dbu = BRL::Genboree::DBUtil.new(gc.dbrcKey, nil, nil)
          dbu.setNewDataDb(@dbName)
          dbu.updateFile2AttributeForFileAndAttrName(@fileId, @gbUploadId, @gbUploadFalseValueId)
          dbu.updateFile2AttributeForFileAndAttrName(@fileId, @gbPartialEntityId, @gbUploadFalseValueId)
          stdin, stdout, stderr = Open3.popen3("sha1sum #{Shellwords.escape(@fullFilePath)}") 
          sha1sum = stdout.readlines[0].split(' ')[0]
          dbu.insertFileAttrValue(sha1sum) 
          gbSha1AttrId = dbu.selectFileAttrNameByName('gbDataSha1').first['id'] 
          gbSha1ValueId = dbu.selectFileAttrValueByValue(sha1sum).first['id'] 
          dbu.insertFile2Attribute(@fileId, gbSha1AttrId, gbSha1ValueId)
          # Submit process file job if required
          if(@extract)
            $stderr.debugPuts(__FILE__, __method__, "STATUS", "Launching a processFile job because user wants to extract file")
            apiCaller = WrapperApiCaller.new(gc.machineName, '/REST/v1/genboree/tool/processFile/job?', @userId) ;
            fileNameInUri = []
            @fileName.split("/").each { |aa|
              fileNameInUri << "#{CGI.escape(aa)}"
            }
            inputs = ["http://#{gc.machineName}/REST/v1/grp/#{CGI.escape(@groupName)}/db/#{CGI.escape(@refseqName)}/file/#{fileNameInUri.join("/")}"] ;
            userRec = dbu.selectUserById(@userId).first ;
            settings = {'unpack' => 'on' } ;
            settings['suppressEmail'] = @suppressEmailForExtractJob
            context = {
                     'toolIdStr' => 'processFile',
                     'queue' => 'gb',
                     'userId' => @userId,
                     'toolTitle' => 'Process File',
                     'userLogin' => userRec['name'],
                     'userLastName' => userRec['lastName'],
                     'userFirstName' => userRec['firstName'],
                     'userEmail' => userRec['email'],
                     'gbAdminEmail' => gc.gbAdminEmail
                   } ;
            outputs = [] ;
            apiCaller.put({'inputs' => inputs, 'outputs' => outputs, 'settings' => settings, 'context' => context }.to_json) ;
            if(apiCaller.succeeded?)
              $stderr.debugPuts(__FILE__, __method__, "STATUS", "Process File Job Submitted: #{apiCaller.parseRespBody.inspect}")
            else
              raise apiCaller.respBody
            end
          end
        else # This job is coming from project additional pages/files resource. Just do expansion if required
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Job is coming from project additional pages/files resource.")
          if(@extract)
            cmd = "expander.rb -f #{CGI.escape(@fullFilePath)} -r"
            system(cmd)
            exitObj = $?.dup
            if(exitObj.exitstatus != 0)
              raise "FATAL: Expander failed. ExitObject: #{exitObj.inspect}. Command: #{cmd.inspect}"
            end
          end
        end
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "All Done.")
      rescue => err
        @err = err
        @errUserMsg = err.message
        $stderr.debugPuts(__FILE__, __method__, "ERROR", "Error:\n#{err}\n\nBacktrace:\n#{err.backtrace.join("\n")}")
        @exitCode = 30
      end
      return @exitCode
    end

    
    # Send success email
    # [+returns+] emailObj or nil
    def prepSuccessEmail()
      return nil
    end

    # Send failure/error email
    # [+returns+] emailObj or nil
    def prepErrorEmail()
      return nil
    end

  end
end; end ; end ; end

# IF we are running this file (and not using it as a library), run it:
if($0 and File.exist?($0) and BRL::Script::runningThisFile?($0, __FILE__, true))
  # Argument to main() is your specific class:
  BRL::Genboree::Tools::main(BRL::Genboree::Tools::Scripts::LocalFileProcessor)
end
