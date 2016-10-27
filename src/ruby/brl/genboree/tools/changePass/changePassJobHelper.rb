require 'json'
require 'brl/util/util'
require 'brl/genboree/genboreeUtil'
require 'uri'
require 'brl/util/emailer'
require "brl/genboree/tools/workbenchJobHelper"

module BRL ; module Genboree ; module Tools
  class ChangePassJobHelper < WorkbenchJobHelper

    TOOL_ID = 'changePass'

    # Instance vars that should be overridden to launch the job
    def initialize(toolIdStr, genbConf=nil, dbu=nil, *args)
      super(toolIdStr, genbConf, dbu, args)
    end

    def runInProcess
      success = true
      settings = @workbenchJobObj.settings
      login = settings['login'].strip
      newPass = settings['newPass'].strip
      @dbu.updateLoginAndPassByUserId(login, newPass, @workbenchJobObj.context['userId'])
      return success
    end

  end
end ; end ; end # module BRL ; module Genboree ; module Tools
