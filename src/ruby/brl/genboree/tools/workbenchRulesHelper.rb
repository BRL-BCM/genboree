require 'tempfile'
require 'json'
require 'brl/util/util'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/tools/toolConf'
require 'brl/genboree/tools/viewHelper'
require 'brl/genboree/tools/accessHelper'
require 'brl/genboree/tools/toolConfHelper'
require 'brl/genboree/rest/data/workbenchJobEntity'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/cache/helpers/dnsCacheHelper'

# pre define mixin modules to prevent namespace errors with potential circular dependencies
module BRL; module Genboree; module Tools; module ViewHelper; end; end; end; end
module BRL; module Genboree; module Tools; module AccessHelper; end; end; end; end
module BRL; module Genboree; module Tools; module ToolConfHelper; end; end; end; end

module BRL ; module Genboree ; module Tools
  class WorkbenchRulesHelper
    include BRL::Cache::Helpers::DNSCacheHelper::CacheClassMethods

    # ------------------------------------------------------------------
    # MIXINS - bring in some generic useful methods used here and elsewhere
    # ------------------------------------------------------------------
    include BRL::Genboree::Tools::ViewHelper
    include BRL::Genboree::Tools::AccessHelper
    include BRL::Genboree::Tools::ToolConfHelper

    # ------------------------------------------------------------------
    # CONSTANT
    # ------------------------------------------------------------------

    TOOL_ID = "[NOT SET]"

    # ------------------------------------------------------------------
    # ACCESSORS
    # ------------------------------------------------------------------

    attr_accessor :genbConf
    attr_accessor :workbenchRules
    attr_accessor :rackEnv
    attr_accessor :rejectionMsg
    attr_accessor :warningMsg

    # A DBRC instance targetting the superuser API-oriented DBRC record for this local Genboree instance
    attr_accessor :superuserApiDbrc
    # A DBRC instance targetting the superuser DB-oriented DBRC record for this local Genboree instance
    attr_accessor :superuserDbDbrc
    # @return [BRL::Genboree::Tool::ToolConf] a @ToolConf@ instance for this tool.
    attr_accessor :toolConf
    # A user-specific Hash of canonical address of hostName => [ login, password, recType] where recType is :internal or :external
    attr_accessor :hostAuthMap
    # Api Helper classes
    attr_accessor :dbApiHelper, :fileApiHelper, :sampleApiHelper, :trkApiHelper, :classApiHelper, :sampleSetApiHelper,
                  :grpApiHelper, :prjApiHelper, :trackEntityListApiHelper, :fileEntityListApiHelper, :sampleEntityListApiHelper
    # Maximum number of target tracks allowed with the selected ROI track
    attr_accessor :maxTargetTargetsAllowed
    # Does payload has settings?
    attr_accessor :payloadHasSettings

    # ------------------------------------------------------------------
    # INSTANCE METHODS
    # ------------------------------------------------------------------
    #
    def initialize(toolIdStr=nil, genbConf=nil, dbu=nil, *args)
      @genbConf = genbConf || BRL::Genboree::GenboreeConfig.load()
      @toolConf = (toolIdStr ? BRL::Genboree::Tools::ToolConf.new(toolIdStr) : nil)
      # Get superuser API and DB dbrcs for this host (will be used to look up any per-user API credential info)
      @superuserApiDbrc = @superuserApiDbrc || BRL::Genboree::GenboreeUtil.getSuperuserDbrc(@genbConf)
      @superuserDbDbrc = @superuserDbDbrc || BRL::Genboree::GenboreeUtil.getSuperuserDbrc(@genbConf, @genbConf.dbrcFile, :db)
      # User specifc auth map automatically populated from local Genboree's externalHostAccess table.
      @hostAuthMap = nil
      @workbenchRules = {}
      @toolIdStr = toolIdStr
      @dbu = dbu
      @rejectionMsg = @warningMsg = @maxTargetTargetsAllowed = nil
      loadRulesFiles(@toolIdStr)
    end

    # INTERFACE METHOD. Implement any non-rule-file, non-generic checks & tests the tool
    # requires on the inputs, outputs, and settings here. This method is called automatically
    # by the default/standard implementation of "rulesSatisfied?()".
    # NOTE: some things are checked AUTOMATICALLY prior to this:
    # 1. Does the job entity satisfy all the rules in the tool's rules file (for the appropriate sections).
    # 2. Does the user have READ access to the GROUPS mentioned in the input URIs? (tracks also checked)
    # 3. Does the user have WRITE access to the GROUPS mentioned in the outputs?
    #
    # If the tool requires MORE checking, and lots do, implement those checks here. If the above
    # checks fail, this method will NOT be called at all (i.e. unnecessary).
    #
    # NOTE: If your checking is actually a common and pretty generic thing, DO NOT COPY-PASTE IT EVERYWHERE.
    # Implement a sensible helper method that does the check, given some inputs. For example: database
    # version checking to make sure all input databases mentioned match the output databases mentioned.
    #
    # NOTE: If returning false, make sure to set wbJobEntity['wbErrorMsg'] to a user-readable string
    # that summarizes the error! That is REQUIRED for the error to be noticed and shown to the user.
    def customToolChecks(wbJobEntity, sectionsToSatisfy=[ :inputs, :outputs, :context, :settings ], toolIdStr=@toolIdStr)
      return true
    end

    # INTERFACE METHOD. Avoid overriding if possible. It should be unnecessary, especially given
    # customToolChecks().
    #
    # Before overriding, consider adding your extra checks GENERICALLY using
    # the approach of customToolChecks(): an optional method whose default implementation returns
    # true, but which some tools can implement for some specific type of ~common checking.
    #
    # NOTE NOTE: there is an analogous JAVASCRIPT version of this function in
    # htdocs/javaScripts/workbench/rules.js called toolsSatisfiedInfo(). Fixes
    # here and there should be kept in sync as appropriate when bugs or speedups are addressed.
    #
    # This default should always be called first thing (via super()) and the return value checked,
    # even if overriding this method in a subclass because it will:
    # (a) validate the sections against the simple rules file for the tool.
    # (b) check user has write ability on all outputs
    # (c) check user has read ability on all inputs
    #
    # When overriding, you first do retVal=super() so the code belove is checked. If the super()
    # call succeeds, your then do your additional checks and validations.
    def rulesSatisfied?(wbJobEntity, sectionsToSatisfy=[ :inputs, :outputs, :context, :settings ], toolIdStr=@toolIdStr)
      # Ensure we have the @toolConf set if it han't been already (as is case when RulesHelper made without a toolIdStr)
      @toolConf = BRL::Genboree::Tools::ToolConf.new(toolIdStr) if(toolIdStr and @toolConf.nil?)
      retVal = false
      # Get user's host-auth info, for user mentioned in @workbenchJobObj. Can be empty for fake @userId (like 0 for public user)
      @hostAuthMap = initUserInfo(wbJobEntity)
      # (a) Check against tool's simple rules
      retVal = checkToolRules(wbJobEntity, sectionsToSatisfy, toolIdStr)
      if(retVal)  # then simple tool rules ok
        # (b) Check user can write to all output targets
        retVal = testUserPermissions(wbJobEntity.outputs, 'w')
        unless(retVal)
          wbJobEntity.context['wbErrorMsg'] = "NO WRITE PERMISSION: You do not have permission to write to the output target#{wbJobEntity.outputs.size > 1 ? 's' :''}. Please contact your user group administrator to arrange write-access."
        else
          # (c) Check user has read ability on all inputs
          retVal = testUserPermissions(wbJobEntity.inputs, 'r')
          unless(retVal)
            wbJobEntity.context['wbErrorMsg'] = "NO READ PERMISSION: You do not have permission to read ALL the data provided as input. Please contact your user group administrator to arrange read-access."
          else
            # (d) Do any additional checks this tool specifically requires
            retVal = customToolChecks(wbJobEntity, sectionsToSatisfy, toolIdStr)
          end
        end
      end
      # Done: we know if all rule sections were satisfied. retVal should have been set to true by all or false by one
      return retVal
    end

    # ------------------------------------------------------------------
    # HELPER METHODS - typically not candidates for overriding, just useful
    # for some RulesHelper subclasses to have available
    #------------------------------------------------------------------
    #
    # Takes an array of REST URIs and checks the database version/build of all resources
    # Skips any non db resource, if any, by default
    # [+uris+] array of REST URIs (of db and resources falling under the db resource)
    # [+skipNonDbUris+] default: true
    # [+returns+] boolean true/false
    def checkDbVersions(uris, skipNonDbUris=true)
      retVal = true
      uris = [uris] if(!uris.is_a?(Array))
      dbVer = nil
      uris.each { |uri|
        # Check if uri has db
        if(@dbApiHelper.extractName(uri))
          if(dbVer.nil?)
            dbVer = @dbApiHelper.dbVersion(@dbApiHelper.extractPureUri(uri), @hostAuthMap)
          else
            if(dbVer != @dbApiHelper.dbVersion(@dbApiHelper.extractPureUri(uri), @hostAuthMap))
              retVal = false
              break
            end
          end
        else # grp or project resource?
          if(skipNonDbUris)
            next
          else
            retVal = false
            break
          end
        end
      }
      return retVal
    end

    # Checks if the job is to be reject if the value (number of target tracks multiplied by the number of annotations in the ROI track)
    # exceeds the cutoff value. This method is only relevant for jobs which include a Regions of Interest (ROI) track.
    # [+uri+] URI of the ROI track
    # [+userId+]
    # [noOfTargets]
    # [+dbVersion+]
    # [+returns+] boolean true/false
    def checkCutoff(uri, userId, noOfTargets, dbVersion)
      retVal = true
      annosCount = @trkApiHelper.getAnnosCount(uri, userId, hostAuthMap=nil)
      trackName = @trkApiHelper.extractName(uri)
      roiTracksCutoff = roiList = nil
      roiList = ( dbVersion == 'hg18' ? @genbConf.ROITrackList_hg18 : @genbConf.ROITrackList_hg19 )
      roiTracksCutoff = ( roiList.include?(trackName) ? @genbConf.ROITrackCutoff_fixed.to_i : @genbConf.ROITrackCutoff_custom.to_i )
      cutoff = (noOfTargets * annosCount)
      if(cutoff > roiTracksCutoff)
        retVal = false
        @maxTargetTargetsAllowed = roiTracksCutoff / annosCount
      end
      return retVal
    end

    # ------------------------------------------------------------------
    # PROTECTED METHODS - not candidates for overriding, in general
    # ------------------------------------------------------------------
    #
    # Checks the simple rules in the tool's rules file.
    def checkToolRules(wbJobEntity, sectionsToSatisfy=[ :inputs, :outputs, :context, :settings ], toolIdStr=@toolIdStr)
      # Ensure we have the @toolConf set if it han't been already (as is case when RulesHelper made without a toolIdStr)
      @toolConf = BRL::Genboree::Tools::ToolConf.new(toolIdStr) if(toolIdStr and @toolConf.nil?)
      retVal = false
      # Get rules for tool:
      toolRules = @workbenchRules[toolIdStr]
      # Go through the rules for each section
      sectionsToSatisfy.each { |section|
        sectionSatisfied = false
        # Section rules:
        sectionRules = toolRules[section.to_s]
        # Workbench JSON contents for section:
        wbSectionContents = wbJobEntity.getSection(section)
        # Evaluate :inputs and :outputs sections differently than :context and :settings
        if(section == :inputs or section == :outputs)

          # Do we satisfy overall item count in this section?
          minItemCount = sectionRules["minItemCount"]
          maxItemCount = sectionRules["maxItemCount"]
          # Set rules satisfied to true if this special tag is set. The inputs have been manipulated in this case
          if(wbJobEntity.settings.key?('positionalInputsTool'))
            sectionSatisfied = true
          else
            if((minItemCount and wbSectionContents.length < minItemCount) or (maxItemCount and wbSectionContents.length > maxItemCount)) # NO, not right number of items
              @rejectionMsg = "Wrong number of items in the '#{section.to_s.capitalize}'."
              sectionSatisfied = false ;
            else # YES, have right number of items...
              # BUT:
              # a. are they acceptable KINDS of items?
              # b. is every item covered by one of the rules?
              # c. is every rule satified?
              # The item rules:
              rulesArray = sectionRules["ruleSet"]
              # If no rules, then this section is satisfied (enforcing empty is done already via minItemCount, maxItemCount)
              # else, section not satisfied unless all rules satisfied
              if(rulesArray.length <= 0)
                sectionSatisfied = true ;
              else
                sectionSatisfied = false ;
                # Create array of same size as contents, but with booleans indicating
                # if the item at that index has already been matched by a rule yet or not.
                wbContentsMatched = wbSectionContents.map { |xx| false }

                # Loop over each rule record in the ruleset array and try to match it against
                # as-yet UNMATCHED items in the workbenchSectionContents.
                rulesArray.each { |ruleRec|
                  ruleRecSatisfied = false
                  # Get the regexp that the item would need to match:
                  ruleRE = /#{ruleRec[0]}/
                  # Get the min and max counts for this rule... need to satisfy these by the end of examining each item in workbenchSectionContents
                  minCount = ruleRec[1] || 0 # null minCount same as 0
                  maxCount = ruleRec[2]
                  # Examine each as-yet UNMATCHED item in workbenchSectionContents and see if the current rule matches it.
                  itemsMatchingCount = 0
                  wbSectionContents.each_index { |ii|
                    unless(wbContentsMatched[ii]) # only looking at as-yet unmached items
                      # Get the actual item to examine
                      wbSectionItem = wbSectionContents[ii]
                      # If it matches the current rule, mark it as matched (so it's skipped when evaluating subsequent rule records)
                      # and increment the count of items matching this rule.
                      if(wbSectionItem =~ ruleRE)
                        wbContentsMatched[ii] = true
                        itemsMatchingCount += 1
                      end
                    end
                  }
                  # Done: All as-yet unmatched items examined against the current rule record.
                  # Did we satisfy the minimum for this rule? (null means there is no minimum; same as minimum of 0)
                  if(itemsMatchingCount >= minCount)
                    # Minimum satisfied.
                    # Did we satisfy the maximum for this rule? (null means there is no maximum; "infinity")
                    if(maxCount.nil? or itemsMatchingCount <= maxCount)
                      # Both min and max satisfied. This rule record is satisfied.
                      ruleRecSatisfied = true ;
                    end
                  end

                  # If this rule record wasn't satisfied we might as well stop
                  # looking at the other rules, since all rules must be satisfied for the ruleset to be satisfied.
                  if(ruleRecSatisfied) # then good for this rule in this section
                    sectionSatisfied = true
                  else # this rule rec failed
                    sectionSatisfied = false
                    break
                  end
                }
                # Done: evaluating each rule in this rule section (assuming there were any).
                if(sectionSatisfied) # so far, so good for this section
                  # But, was EVERY item in this section matched by a rule?
                  wbContentsMatched.each { |matched|
                    unless(matched)
                      # item corresponding to this was not matched, break out early
                      sectionSatisfied = false
                      @rejectionMsg = "One or more items in the '#{section.to_s.capitalize}' is a type not accepted by this tool."
                      break # out of wbContentsMatched iterator
                    end
                  }
                else # at least one rule in this section not satisfied
                  @rejectionMsg = "One or more items in the '#{section.to_s.capitalize}' is a type not accepted by this tool, or there are not the right number of items."
                end
              end # if(rulesArray.length <= 0)
            end # if((minItemCount and wbSectionContents.length < minItemCount) or (maxItemCount and wbSectionContents.length > maxItemCount)) # NO, not right number of items
          end
        else # section is "context" or "settings"
          # Ensure required fields are present
          requirementMissing = false
          if(!sectionRules.nil? and !sectionRules['required'].nil? and !sectionRules['required'].empty?)
            requiredArray = sectionRules['required']
            # Loop through required fields array ensuring they're not nil
            requiredArray.each { |reqField|
              if(wbSectionContents[reqField].nil?)
                wbJobEntity.context['wbErrorMsg'] = "Required field \"#{reqField}\" is missing from \"#{section}\"."
                requirementMissing = true
                break
              end
            }
          end
          if(requirementMissing)
            sectionSatisfied = false
          else
            # If there is a 'patterns' section defined confirm that the fields match the patterns
            # The 'patterns' rules section is hash containing keys that correspond to the name/id of the input elements
            # and the value is an array containing a regular expression as the first element and an
            # error message as the second element.
            patternFailed = false
            if(!sectionRules.nil? and !sectionRules['patterns'].nil? and !sectionRules['patterns'].empty?)
              patternsHash = sectionRules['patterns']
              # Loop through the patterns matching
              patternsHash.each_pair { |field, patternArr|
                regex = patternArr[0]
                errorMsg = patternArr[1]
                ruleRE = /#{regex}/
                #$stderr.puts "DEBUG: \nfield: #{field.inspect} ; wbSectionContents[field]: #{wbSectionContents[field].inspect}\nDEBUG: ruleRE: #{ruleRE.source}"
                # Some form fields like checkboxes are present/not-present. So if not present, the value will be nil.
                # By doing .to_s, such values allow the ruleRE to match against "", which can be permitted.
                if(wbSectionContents[field].to_s =~ ruleRE)
                  patternFailed = false
                else
                  wbJobEntity.context['wbErrorMsg'] = "#{errorMsg} (Incorrect format for field \"#{field}\".)"
                  patternFailed = true
                  break
                end
              }
            end
            if(patternFailed)
              sectionSatisfied = false
            else
              # If settings has special settings 'multiSelectList' it cannot be empty
              if(wbJobEntity.settings['multiSelectInputList'] and wbJobEntity.settings['multiSelectInputList'].empty?)
                wbJobEntity.context['wbErrorMsg'] = "No inputs selected from the input list."
              else
                sectionSatisfied = true
              end
            end
          end

        end # if(section == :inputs or section == :outputs)
        # Completely done with this rule section.
        # Was the rule section completely satisfied? If not, stop (by returning early from the ruleset.each() callback)
        # and don't bother evaluating other rule sections since all rule sections must be satisfied for the ruleset to be satisfied.
        if(sectionSatisfied) # section looks ok
          retVal = true
        else
          retVal = false  # return early from code block
          break # out of sectionsToSatisfy iterator
        end
      }
      # Done: we know if all rule sections were satisfied. retVal should have been set to true by all or false by one
      return retVal
    end

    def loadRulesFiles(toolIdStr=nil)
      baseDir = @genbConf.resourcesDir
      toolsDir = "#{baseDir}/tools"
      # Read ALL tools' rules or just 1 tool's?
      if(toolIdStr) # a specific tool's
        rulesFile = "#{toolsDir}/#{toolIdStr}/rules/workbench.rules.json"
        self.readToolRuleFile(rulesFile)
      else # ALL tools'
        Dir.foreach(toolsDir) { |entry|
          fullPath = "#{toolsDir}/#{entry}"
          next if(!File.directory?(fullPath) or entry =~ /^\./ or entry =~ /^default/)
          rulesFile = "#{fullPath}/rules/workbench.rules.json"
          self.readToolRuleFile(rulesFile, entry)
        }
      end
    end

    def readToolRuleFile(rulesFile, toolIdStr=@toolIdStr)
      if(File.exist?(rulesFile))
        begin
          rulesStr = File.read(rulesFile)
          rulesObj = JSON.parse(rulesStr)
        rescue => err
          $stderr.puts "ERROR: [non-fatal, try to continue] Could not read or parse rules file for #{toolIdStr.inspect}. Will try to proceed without this tool and its file. STACKTRACE:\n#{err.message}\n#{err.backtrace.join("\n")}"
        end
        # Pre-instantiate the RegExps in inputs and outputs ruleSet so we don't do it more
        # than once for this object (e.g. not each time rulesSatisfied? is called)
        unless(rulesObj.nil?)
          begin
            [ "inputs", "outputs"].each { |section|
              sectionObj = rulesObj[section]
              rulesObj[section] = sectionObj = { 'maxItemCount' => 0, 'minItemCount' => 0, 'ruleSet' => [] } unless(sectionObj)
              rulesArray = ( sectionObj['ruleSet'] or [] )
              rulesArray.each { |rule|
                rule[0] = /#{rule[0]}/
                rule[1] = 0 if(rule[1].nil?)
              }
            }
            # Store this tool's rules
            @workbenchRules[toolIdStr] = rulesObj
          rescue => err
            $stderr.puts "ERROR: [non-fatal, try to continue] Found and parsed tool rule file for #{toolIdStr.inspect}. But has unexpected and unacceptable content/structure. Will try to proceed without this tool and its file. STACKTRACE:\n#{err.message}\n#{err.backtrace.join("\n")}"
          end
        end
      else
        $stderr.puts "WARNING: No workbench.rules.json in rules/ dir for tool '#{toolIdStr}'"
      end
    end

    def rulesForTool(toolIdStr)
      return @workbenchRules[toolIdStr]
    end

    def buildRuleJavascriptHash(jsHashVarName='wbRulesHash')
      # Tmp javascript vars to speed things up (fewer function calls)
      # and nitialize the javascript hash variable name.
      buff = "\nvar tmpToolRules ; var tmpSectionRules ;\n var tmpRuleSetArray ;\n#{jsHashVarName} = new Hash() ;\n"
      @workbenchRules.each_key { |toolId|
        buff << "\n"
        # Initialize the rule set for this tool:
        buff << "#{jsHashVarName}.set('#{toolId}', new Hash()) ;\n"
        buff << "tmpToolRules = #{jsHashVarName}.get('#{toolId}') ;\n"
        # Go through each section of the ruleSet
        toolRules = @workbenchRules[toolId]
        toolRules.each_key { |ruleSection|
          rules = toolRules[ruleSection]
          buff << "tmpToolRules.set('#{ruleSection}', new Hash()) ;\n"
          buff << "tmpSectionRules = tmpToolRules.get('#{ruleSection}', new Hash()) ;\n"
          # If the section is inputs or outputs, we need to pre-make the javascript RegExp object that's in the rule triple.
          if(ruleSection == "inputs" or ruleSection == "outputs")
            # Go through each entry of this section's named rules:
            rules.each_key { |ruleKey|
              ruleSet = rules[ruleKey]
              # If the ruleSet named rule, make equivalent Javascript rule array triple.
              if(ruleKey == "ruleSet" and !ruleSet.nil? and !ruleSet.empty?)  # then a non empty ruleSet
                # Create ruleSet array on javascript side
                buff << "tmpSectionRules.set('ruleSet', []) ;\n"
                buff << "tmpRuleSetArray = tmpSectionRules.get('ruleSet') ;\n"
                # Go through each rule in the ruleSet and add to javascript's ruleSet
                ruleSet.each { |rule| # rule is a triple with form [ RegExp, minCount, maxCount ]
                  buff << "tmpRuleSetArray.push([ new RegExp(#{rule[0].source.to_json}), #{(rule[1].nil? ? 0 : rule[1].to_json)}, #{rule[2].to_json} ]) ;\n"
                }
              else # just a regular key-value pair
                buff << "tmpSectionRules.set('#{ruleKey}', #{rules[ruleKey].to_json}) ;\n"
              end
            }
          # Else the section is settings or context, just set the named rules
          else
            buff << "tmpSectionRules.set(#{rules.to_json}) ;\n"
          end
        }
      }
      buff << "\n"
      return buff
    end

    # Check if the job has generated any warnings. As long as this method returns true, a warning dialog
    #   will be displayed whenever the submit button of the usual workbench tool dialog is clicked.
    # The contents of the actual warning dialog are up to the sub class implementation, but typically
    #   the UI rhtml and the RulesHelper child coordinate on one or more shared attribute names
    #   in wbJobEntity including:
    #   (1) wbJobEntity.context["wbErrorMsg"] - the warning message to display
    #   (2) wbJobEntity.context["wbErrorMsgHasHtml"] - if the wbErrorMsg contains html content and should be
    #     inserted as is into a dialog box or if html content (<p>, etc.) should be added to it
    #   (3) wbJobEntity.context["warningsConfirmed"] - set to true if the user accepts the warning message
    # @param [BRL::Genboree::REST::Data::WorkbenchJobEntity] wbJobEntity
    # @return [Boolean] if true there are (further) warning messages to be displayed
    def warningsExist?(wbJobEntity)
      false
    end

    # Check if {type} container (1) has items and (2) user can access those items
    #   along with other features mentioned in the return value documentation
    # @param [Array<String>] parentArray container uris to expand and provide uris for children within them
    # @param [:sample, :file, :track] type of API helper to use
    # @param [Fixnum] userId user information to determine access
    # @param ['r', 'w', 'o'] accessCode the level of access to verify the user has
    # @return [Array]
    #   access [Boolean] if user has {accessCode} level of access to items in non-empty containers
    #   context [Hash] adds wbErrorMsg if user does not have access, may set wbErrorMsgHasHtml
    #     intended for a merge into the actual wbJobEntity.context hash (may override existing error messages)
    #   childArray [Array<String>] children of items in parentArray, with order preserved (same order as parents)
    #     and with uniqueness enforced (if two parents claim the same child, the latter parent is ignored)
    # @todo TODO asking for type here may be undesirable -- programmers may need to check
    #   the types of URIs in the input array before calling this method (which happens redundantly again in the body of this method)
    def childrenAccessible?(parentArray, type, userId, accessCode)
      access = true
      context = {}
      childArray = []

      # transform container uris to item-in-container uris
      type2Helper = {:sample => @sampleApiHelper, :file => @fileApiHelper, :track => @trackApiHelper}
      apiHelper = type2Helper[type]
      unless(type2Helper.key?(type))
        # then user provided a bad type
        raise ArgumentError, "Bad type=#{type}; please provide one of #{type2Helper.keys.join(", ")}."
      end
      unless(apiHelper)
        raise ArgumentError, "the api helper for #{type} is not instantiated properly; cannot determine if children are accessible"
      end

      # TODO sets @err if API server is down or inputs are not recognized as a container of {type}
      #   (being a {type} itself is ok)
      childArray = apiHelper.expandContainers(parentArray, userId)
      containers2Children = apiHelper.containers2Children # set by expandContainers

      # verify the expanded uris are accessible at level {accessCode}
      if(childArray.nil? or childArray.empty?)

        # extract name from uris to provide a more informative error message
        uri2Meta = apiHelper.classifyUris(parentArray)

        # Create a a list of container names that the user should add samples to before proceeding
        # Only in this case if no sample, file, track, etc. uri is provided, only container uris
        containers = []
        uri2Meta.each_key{|uri|
          metaHash = uri2Meta[uri]
          name = metaHash[:name]
          containers << name
        }

        # set error message
        context['wbErrorMsg'] = "NO #{type.to_s.upcase}: Please add #{type.to_s.downcase} to one of the following inputs using the tools in the \"Data\" menu: "\
                                            "#{containers.join(", ")}"
        access = false
      else
        # check for access on the expanded uris (in case we expanded any entity lists)
        # @grpApiHelper caches results so even redundant group checks should be quick
        # BadUris are those where user has no access
        list2BadUris = {}
        parentArray.each{|input|
          childUris = containers2Children[input]
          childUri2Access = @grpApiHelper.whichAccessibleToUser(childUris, userId, [accessCode])

          badUris = []
          childUri2Access.each_key{|uri|
            access = childUri2Access[uri]
            unless(access)
              badUris << uri
            end
          }
          unless(badUris.nil? or badUris.empty?)
            # must be because an entity list contains items that are no longer accessible
            # since all other containers have the same access control
            list2BadUris[input] = badUris
          end
        }

        # notify user of inaccessible items in form
        # msg:
        #   entityList1:
        #     uri1
        #     uri2
        #   entityList1:
        #     uri3
        unless(list2BadUris.empty?)
          # list of entity lists with inaccessible contents
          listStr = "<ul>\n"
          list2BadUris.each_key{|listUri|
            badUris = list2BadUris[listUri]
            listStr << "<li>#{listUri}:\n"

            # which items in entity list cant be accessed
            listStr << "<ul>\n"
            badUris.each{|uri|
              listStr << "<li>#{uri}</li>\n"
            }
            listStr << "</ul>\n"

            listStr << "</li>\n"
          }
          listStr << "</ul>"
          context['wbErrorMsg'] = "NO READ ACCESS: You do not have read access to the following #{type.to_s.downcase}(s) found within your input entity list(s): "\
                                              "#{listStr}"
          context['wbErrorMsgHasHtml'] = true
          access = false
        end
      end
      return access, context, childArray
    end

    def logAndPrepareError(err, wbJobEntity)
      defaultMsg = "Unhandled exception. Please contact the administrator at #{@genbConf.send(:gbAdminEmail)}."
      $stderr.debugPuts(__FILE__, __method__, "ERROR", "Message: #{err.message} ; backtrace:\n#{err.backtrace.join("\n")}\n\n")
      if(err.is_a?(BRL::Genboree::GenboreeError))
        wbJobEntity.context['wbErrorMsg'] = err.message
        wbJobEntity.context['wbErrorName'] = err.type
      else
        wbJobEntity.context['wbErrorMsg'] = defaultMsg
        wbJobEntity.context['wbErrorName'] = :"Internal Server Error"
      end
      return nil
    end
  end
end ; end end # module BRL ; module Genboree ; module Tools
