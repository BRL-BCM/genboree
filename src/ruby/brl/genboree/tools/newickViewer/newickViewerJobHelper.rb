require 'json'
require 'brl/util/util'
require 'brl/genboree/genboreeUtil'
require 'uri'
require "brl/genboree/tools/workbenchJobHelper"
require 'brl/dataStructure/newickTree'
require 'brl/genboree/graphics/d3/d3circularDendogram'
require 'brl/genboree/graphics/d3/d3circularDendogramRotatable'
require 'brl/genboree/graphics/d3/d3horizontalDendogram'
require 'brl/genboree/graphics/d3/d3horizontalDendogramCollapsible'
require 'brl/genboree/rest/wrapperApiCaller'
include BRL::Genboree::REST

module BRL ; module Genboree ; module Tools
  class NewickViewerJobHelper < WorkbenchJobHelper

    TOOL_ID = 'newickViewer'

    # Instance vars that should be overridden to launch the job
    def initialize(toolIdStr, genbConf=nil, dbu=nil, *args)
      super(toolIdStr, genbConf, dbu, args)
    end

    def runInProcess()
      success = true
      begin
        inputs = @workbenchJobObj.inputs
        userId = @workbenchJobObj.context['userId']
        fileUriObj = URI.parse(inputs[0])
        apiCaller = ApiCaller.new(fileUriObj.host, "#{fileUriObj.path}/data?", @hostAuthMap)
        apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
        fileName = "#{Time.now.to_f}.#{rand(10_000)}.#{CGI.escape(File.basename(@fileApiHelper.extractName(inputs[0])))}"
        newickBuff = ""
        dObj = nil
        dendogram = @workbenchJobObj.settings['dendogram']
        apiCaller.get() { |chunk| newickBuff << chunk }
        ntreeObj = BRL::DataStructure::NewickTree.new(newickBuff)
        if(dendogram == 'cd')
          dObj = BRL::Genboree::Graphics::D3::D3CircularDendogram.new(ntreeObj)
        elsif(dendogram == 'hd')
          dObj = BRL::Genboree::Graphics::D3::D3HorizontalDendogram.new(ntreeObj)
        elsif(dendogram == 'hdc')
          startWith = @workbenchJobObj.settings['startWith']
          dObj = BRL::Genboree::Graphics::D3::D3HorizontalDendogramCollapsible.new(ntreeObj)
          dObj.toggleType = startWith
        elsif(dendogram == 'cdr')
          dObj = BRL::Genboree::Graphics::D3::D3CircularDendogramRotatable.new(ntreeObj)
        end
        @workbenchJobObj.settings['d3JsCode'] = dObj.makeJS()
      rescue => err
        $stderr.puts err
        $stderr.puts err.backtrace.join("\n")
        success = false
        @workbenchJobObj.context['wbErrorMsg'] = "FATAL ERROR: Could not set up newick data object in job helper."
      end
      return success
    end

  end
end ; end ; end # module BRL ; module Genboree ; module Tools
