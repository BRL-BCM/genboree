require 'brl/genboree/tools/workbenchJobHelper'

module BRL; module Genboree; module Tools
  class ErccFinalProcessingJobHelper < WorkbenchJobHelper
    TOOL_ID = "erccFinalProcessing"

    def initialize(toolIdStr, genbConf=nil, dbu=nil, *args)
      super(toolIdStr, genbConf, dbu, args)
      self.class.commandName = "erccFinalProcessingWrapper.rb"
    end

    # INTERFACE METHOD. Returns a Hash with various special job directives
    # or nil if there are none (basic/simple cluster job). In this tool,
    # ppn, nodes, mem, vmem, etc, are determined dynamically based
    # on user selected option. If user selects exogenous mapping to both miRNA and genomes, 
    # which uses STAR mapping, then set mem/vmem to 100GB. Else, set mem/vmem to 124GB
    # @return [Hash] with one or more key-values for @:ppn@, @:nodes@, @:pvmem@
    def directives()
      directives = super()
      isFTPJob = workbenchJobObj.settings['isFTPJob']
      if(isFTPJob)
        directives[:mem] = "32gb"
        directives[:vmem] = "32gb"
        $stderr.puts "isFTPJob: #{isFTPJob} ==> New Directives: #{directives.inspect}"
      end
      return directives
    end

    # We override the configQueue method so that we can submit exogenous mapping jobs to a different queue (gbLowParallel) from other jobs (gbMultiCore)
    # We do this in order to keep a solid limit on how many exogenous mapping jobs can run at a given time (4, currently) so that they don't overrun all
    # of our available high capacity nodes.
    def configQueue(workbenchJobObj)
      super(workbenchJobObj)
      isFTPJob = workbenchJobObj.settings['isFTPJob']
      if(isFTPJob)
        workbenchJobObj.context['queue'] = "gbRamHeavy"
      end
      return workbenchJobObj.context['queue']
    end

  end
end; end; end
