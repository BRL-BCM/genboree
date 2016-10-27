require 'json'
require 'brl/util/util'
require 'brl/genboree/dbUtil'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require "brl/genboree/rest/helpers/fileApiUriHelper"
require "brl/genboree/tools/workbenchJobHelper"
require "brl/genboree/tools/workbenchRulesHelper"
require 'brl/genboree/helpers/expander'
require 'brl/util/convertText'
require 'brl/genboree/abstract/resources/user'
require 'uri'
require 'json'

module BRL ; module Genboree ; module Tools
  class SetTrackMetaDataJobHelper < WorkbenchJobHelper

    TOOL_ID = 'setTrackMetaData'

    # Instance vars that should be overridden to launch the job
    def initialize(toolIdStr, genbConf=nil, dbu=nil, *args)
      super(toolIdStr, genbConf, dbu, args)
      self.class.commandName = ""
    end

   def runInProcess()
      success = true

      # We need to validate the file that was uploaded
      dbFileRsrc = @workbenchJobObj.inputs.first
      inputs = @workbenchJobObj.inputs
      outputs = @workbenchJobObj.outputs
      @apiDbrc = @superuserApiDbrc
      # Need to extract group, db and file names from uri
      fileName = @fileApiHelper.extractName(dbFileRsrc)
      dbName = @fileApiHelper.dbApiUriHelper.extractName(dbFileRsrc)
      grpName = @fileApiHelper.dbApiUriHelper.grpApiUriHelper.extractName(dbFileRsrc)
      @uri = URI.parse(dbFileRsrc)
      @fileRcscUri = "/REST/v1/grp/#{CGI.escape(grpName)}/db/#{CGI.escape(dbName)}/file/#{CGI.escape(fileName)}/data?"
      outputUri = URI.parse(outputs[0])
      apiCaller = ApiCaller.new(@uri.host, @fileRcscUri, @hostAuthMap)
      retVal = ""
      # Making internal API call for getting the contents of the metadata file
      apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
      resp = apiCaller.get()
      if(apiCaller.succeeded?)
        retVal = apiCaller.respBody
        # Make Tempfile. Auto-cleaned up when we call close. Use untained Dir::tmpdir as a best practice.
        # - Don't close until all done with the file!
        tmpFileName = "#{Time.now.to_f}.tmp"
        tempFileObj  = Tempfile.new(tmpFileName, Dir::tmpdir.untaint)
        tempFileObj.write(retVal)
        tempFileObj.flush() # ensure contents written to disk...will be reading from disk before we're done with the Tempfile!
        # tempFileObj.path gives full path to temp file
        @exp = BRL::Genboree::Helpers::Expander.new(tempFileObj.path)
        @exp.extract('text')
        @exp.removeIntermediateCompFiles()
        fileList = @exp.uncompressedFileList
        if(fileList.empty?)
          @workbenchJobObj.context['wbErrorName'] = :'Not Found'
          @workbenchJobObj.context['wbErrorMsg'] = "No valid input file found. Either input file has been deleted or your archive does not contain any text file(s). "
          $stderr.puts "TOOL ERROR: (#{File.basename(__FILE__)}) => #{@workbenchJobObj.context['wbErrorName']}: #{@workbenchJobObj.context['wbErrorMsg']}"
          success = false
        end
        fileList.each { |file|
          next if(@exp.isCompressed?(file))
          # Convert to unix format
          convObj = BRL::Util::ConvertText.new(file, true)
          convObj.convertText()
          # Now we make an API call to add the attributes/metadata
          rsrcUri = "#{outputUri.path}/trks/attributes?format=tabbed"
          rsrcUri << "&createEmptyTracks=true" if(workbenchJobObj.settings['createEmptyTracks'])
          apiCaller = ApiCaller.new(outputUri.host, rsrcUri, @hostAuthMap)
          apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
          apiCaller.put(File.read(file))
          if(!apiCaller.succeeded?)
            resp = apiCaller.respBody
            retVal = JSON.parse(resp)
            @workbenchJobObj.context['wbErrorName'] = retVal['status']['statusCode']
            @workbenchJobObj.context['wbErrorMsg'] = retVal['status']['msg']
            @workbenchJobObj.context['wbErrorMsgHasHtml'] = true
            success = false
          else
            retVal = JSON.parse(apiCaller.respBody)
            @workbenchJobObj.context['wbAcceptMsg'] = retVal['status']['msg']
            @workbenchJobObj.context['wbMsgHasHtml'] = true
          end
        }
        # Clean up. Remove tempfile (via close) and any subdir the Expander used
        `rm -rf #{@exp.tmpDir}`
        tempFileObj.close() rescue nil
      else
        resp = apiCaller.respBody
        retVal = JSON.parse(resp)
        @workbenchJobObj.context['wbErrorName'] = retVal['status']['statusCode']
        @workbenchJobObj.context['wbErrorMsg'] = retVal['status']['msg']
        @workbenchJobObj.context['wbErrorMsgHasHtml'] = true
        success = false
      end
      return success
    end
  end
end ; end ; end # module BRL ; module Genboree ; module Tools
