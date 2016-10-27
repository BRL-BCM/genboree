require 'uri'
require 'brl/genboree/tools/workbenchRulesHelper'

module BRL ; module Genboree ; module Tools

  class UploadDbFileRulesHelper < WorkbenchRulesHelper
    def rulesSatisfied?(wbJobEntity, sectionsToSatisfy=[ :inputs, :outputs, :context, :settings ], toolIdStr=@toolIdStr)
      @settingsPresent = sectionsToSatisfy.include?(:settings) ? true : false
      rulesSatisfied = super(wbJobEntity, sectionsToSatisfy, toolIdStr)
      if(rulesSatisfied)
        # ------------------------------------------------------------------
        # CHECK SETTINGS
        # ------------------------------------------------------------------
        if(sectionsToSatisfy.include?(:settings))
          $stderr.puts("settings present")
          # Change the job into a cluster job if post-processing is to be done.
          if(wbJobEntity.settings['unpack'] or wbJobEntity.settings['convToUnix'])
            wbJobEntity.context['queue'] = @genbConf.gbDefaultPrequeueQueue
          end
        end
      end
      return rulesSatisfied
    end
    
    
    def readToolRuleFile(rulesFile, toolIdStr=@toolIdStr)
      if(File.exist?(rulesFile))
        begin
          rulesStr = File.read(rulesFile)
          rulesObj = JSON.parse(rulesStr)
          @rulesObjOrig = rulesObj.dup()
          $stderr.puts("caller: #{caller.inspect}")
          rulesObj['inputs']['maxItemCount'] = 1 if(caller[4] =~ /toolJob\.rb/) # Change the max inputs for the second pass of the rules helper
        rescue => err
          $stderr.puts "ERROR: Could not read or parse rules file for '#{toolIdStr}'. Details:\n#{err.message}\n#{err.backtrace.join("\n")}"
        end
        # Pre-instantiate the RegExps in inputs and outputs ruleSet so we don't do it more
        # than once for this object (e.g. not each time rulesSatisfied? is called)
        unless(rulesObj.nil?)
          [ "inputs", "outputs"].each { |section|
            rulesArray = rulesObj[section]['ruleSet']
            rulesArray.each { |rule|
              rule[0] = /#{rule[0]}/
              rule[1] = 0 if(rule[1].nil?)
            }
          }
          # Store this tool's rules
          @workbenchRules[toolIdStr] = rulesObj
        end
      else
        $stderr.puts "WARNING: No workbench.rules.json in rules/ dir for tool '#{toolIdStr}'"
      end
    end
  end
end; end; end
