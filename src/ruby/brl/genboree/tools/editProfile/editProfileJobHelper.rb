require 'json'
require 'brl/util/util'
require 'brl/genboree/genboreeUtil'
require 'uri'
require 'brl/util/emailer'
require "brl/genboree/tools/workbenchJobHelper"

module BRL ; module Genboree ; module Tools
  class EditProfileJobHelper < WorkbenchJobHelper

    TOOL_ID = 'editProfile'

    # Instance vars that should be overridden to launch the job
    def initialize(toolIdStr, genbConf=nil, dbu=nil, *args)
      super(toolIdStr, genbConf, dbu, args)
    end

    def runInProcess()
      success = true
      settings = @workbenchJobObj.settings
      login = settings['login']
      fName = settings['fName']
      lName = settings['lName']
      inst = settings['inst']
      email = settings['email']
      phone = settings['phone']
      @dbu.updateUserByUserId(login, fName, lName, inst, email, phone, @userId)
      return success
    end

  end
end ; end ; end # module BRL ; module Genboree ; module Tools
