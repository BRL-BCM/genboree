require 'brl/genboree/tools/workbenchJobHelper'
require 'brl/genboree/tools/alleleReg_v1/simpleAlleleRegistrar'

module BRL; module Genboree; module Tools
  class AlleleReg_v1JobHelper < WorkbenchJobHelper

    def initialize(toolIdStr, genbConf=nil, dbu=nil, *args)
      super(toolIdStr, genbConf, dbu, args)
    end

    # Override parent runInProcess() so that we can run on the web server
    # @return [Boolean] whether or not job succeeded
    # @set @workbenchJobObj.results with a Conclusion document
    # @set @workbenchJobObj.context['wbErrorMsg'] if error occurs
    # @todo @workbenchJobObj.settings['updateDoc']
    # @todo would like to put @apiCaller setup in initialize but user authentication hasnt happened at that stage:
    #   it happens with executionCallback is called from the toolJob resource, which in turn executes this function
    def runInProcess()
      $stderr.debugPuts(__FILE__, __method__, "DEBUG", ">>>START runInProcess <<<")
      success = false
      begin
        hgvsVal = @workbenchJobObj.settings['hgvsVal']
        # We should have this in settings already because infrastructure ran our RuleHelper first.
        # But if it's not there, we'll try to rescue things if possible.
        confDocUrl = @workbenchJobObj.settings['alleleRegConfig']
        unless(confDocUrl and confDocUrl =~ /\S/)
          # We will set the alleleRegConfig doc here, from the toolConf
          confDocUrl = @workbenchJobObj.settings['alleleRegConfig'] = @toolConf.getSetting('settings', 'alleleRegConfig')
        end
        if(confDocUrl and confDocUrl =~ /\S/)
          # Instantiate SimpleAlleleRegistrar
          begin
            sar = SimpleAlleleRegistrar.new(confDocUrl, @hostAuthMap)
            sar.rackEnv = @rackEnv
            sar.domainAlias = @genbConf.machineNameAlias
            # Get canoncial allele URL from HGVS
            caUrl = sar.canonicalAlleleURL(hgvsVal, :hgvs)
            # Went ok?
            if(caUrl)
              # Build generic URL doc
              # * @todo There should be a defined Template for this or something?
              resultDoc = makeUrlKbDoc(caUrl)
              @workbenchJobObj.results = resultDoc
              success = true
            else # No, something went wrong
              resultDoc = nil
              @workbenchJobObj.context['wbErrorMsg'] = sar.errMsg
              @workbenchJobObj.context['wbErrorName'] = :'Bad Request'
              success = false
            end
          rescue => err
            # Error init'ing SAR
            @workbenchJobObj.context['wbErrorMsg'] = err.message
            @workbenchJobObj.context['wbErrorName'] = :'Internal Server Error'
            $stderr.debugPuts(__FILE__, __method__, "ERROR", "Instantiating or using the SimpleAlleleRegistrar raised an error.\n  - Message: #{err.message}\n  - Trace:\n#{err.backtrace.join("\n")}\n\n")
          end
        else # bad confDocUrl
          errMsg = "TOOL BUG: The tool is configured INCORRECTLY on this Genboree server. The alleleRegConfig property does not point to a publicly accessible Allele Registration configuration KB Doc that can be used to run the tool appropriately. Please contact your Genboree Administrators for help rectifying this BUG."
          @workbenchJobObj.context['wbErrorName'] = :'Internal Server Error'
          @workbenchJobObj.context['wbErrorMsg'] = errMsg
          $stderr.debugPuts(__FILE__, __method__, "ERROR (CONFIG)", "#{errMsg} The alleleRegConfig property value is:\n    #{alleleRegConfig.inspect}")
          success = false
        end
      rescue => err
        logAndPrepareError(err)
        success = false
      end

      return success
    end

        # @todo this is a generic need for kb modelsHelper
    # @note assumes a certain model for a Conclusion document, @see getConclusionModel
    def makeUrlKbDoc(url)
      kbDoc = BRL::Genboree::KB::KbDoc.new()
      kbDoc.setPropVal("URL", url)
      return kbDoc
    end
  end
end; end; end
