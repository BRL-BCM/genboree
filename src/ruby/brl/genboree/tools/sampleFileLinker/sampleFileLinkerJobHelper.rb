require 'json'
require 'brl/util/util'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/sampleApiUriHelper'
require 'brl/genboree/rest/helpers/sampleSetApiUriHelper'
require "brl/genboree/tools/workbenchJobHelper"
require 'brl/genboree/rest/apiCaller'

module BRL ; module Genboree ; module Tools
  class SampleFileLinkerJobHelper < WorkbenchJobHelper

    TOOL_ID = 'sampleFileLinker'


    # Instance vars that should be overridden to launch the job
    def initialize(toolIdStr, genbConf=nil, dbu=nil, *args)
      super(toolIdStr, genbConf, dbu, args)
      self.class.commandName = "sampleFileLinker.rb"
    end

    # This is where the command is defined
    #
    # WARNING: Be careful when building a command to be executed.
    # Any command line option values must be properly escaped.
    #
    # For example: someone submitted a var @settings['foo'] = ';rm -dfr /'
    # and then you build a command without escaping
    # "myCommand.rb -n #{foo}"  =>  myCommand.rb -n ;rm -dfr /
    # The correct way to do this is using CGI.escape()
    # "myCommand.rb -n #{CGI.escape(foo)}"  =>  myCommand.rb -n %3Brm%20-dfr%20%2F
    #
    # [+returns+] string: the command
    def buildCmd(useCluster=false)
      cmd = ''
      commandName = self.class.commandName
      raise NoMethodError.new("FATAL INTERNAL ERROR: Must have a commandName class instance variable in child class or buildCmd() should be overridden by child class if parent/default executionCallback is used.") if(commandName.nil?)
      if(useCluster)
        cmd = "#{commandName} -j ./#{@genbConf.gbJobJSONFile} "
      else
        cmd = "#{commandName} -j #{@workbenchJobObj.context['scratchDir']}/#{@genbConf.gbJobJSONFile} > #{@workbenchJobObj.context['scratchDir']}/#{commandName}.out 2> #{@workbenchJobObj.context['scratchDir']}/#{commandName}.err"
      end
      return cmd
    end

    # Casts certain args to the tool to integer
    # Also converts /files url to db if required
    # [+workbenchJobObj+]
    # [+returns+] workbenchJobObj
    def cleanJobObj(workbenchJobObj)
      genbConf = ENV['GENB_CONFIG']
      genbConfig = BRL::Genboree::GenboreeConfig.load(genbConf)
      workbenchJobObj.settings['dbuKey'] = genbConfig.dbrcKey
      inputs = []
      dbrcFile = File.expand_path(ENV['DBRC_FILE'])
      user = @superuserApiDbrc.user
      pass = @superuserApiDbrc.password
      workbenchJobObj.inputs.each { |input|
        if(input =~ BRL::Genboree::REST::Helpers::SampleApiUriHelper::NAME_EXTRACTOR_REGEXP) # For sample
          inputs.push(input)
        elsif(input =~ BRL::Genboree::REST::Helpers::SampleSetApiUriHelper::NAME_EXTRACTOR_REGEXP) # For sample set
          uri = URI.parse(input)
          rcscUri = uri.path.chomp("?")
          apiCaller = ApiCaller.new(uri.host, "#{rcscUri}?detailed=true", @hostAuthMap)
          apiCaller.initInternalRequest(@rackEnv, genbConfig.machineNameAlias) if(@rackEnv)
          apiCaller.get()
          if(apiCaller.succeeded?)
            retVal = JSON.parse(apiCaller.respBody)
            data = retVal['data']
            data.each_key { |key|
              if(key == 'sampleList')
                data[key].each { |sampleEntity|
                  inputs.push(sampleEntity['refs'][BRL::Genboree::REST::Data::BioSampleEntity::REFS_KEY])
                }
                break
              end
            }
          else
            wue = BRL::Genboree::Tools::WorkbenchUIError.new(:'MISSING_RESOURCE', "ApiCaller failed for getting samples for: #{input.inspect}. Samples missing?")
            raise wue
          end
        else # file
          inputs.push(input)
        end
      }
      workbenchJobObj.inputs = inputs
      return workbenchJobObj
    end

  end
end ; end ; end # module BRL ; module Genboree ; module Tools
