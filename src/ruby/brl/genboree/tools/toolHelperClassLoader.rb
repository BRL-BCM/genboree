#!/usr/bin/env ruby
require 'brl/util/util'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/groupApiUriHelper'
require 'brl/genboree/rest/helpers/sampleApiUriHelper'
require 'brl/genboree/rest/helpers/sampleSetApiUriHelper'
require 'brl/genboree/rest/helpers/classApiUriHelper'
require 'brl/genboree/rest/helpers/fileApiUriHelper'
require 'brl/genboree/rest/helpers/projectApiUriHelper'
require 'brl/genboree/rest/helpers/trackEntityListApiUriHelper'
require 'brl/genboree/rest/helpers/fileEntityListApiUriHelper'

module BRL ; module Genboree ; module Tools
  # Adds core helpers from ActiveView::Helpers:: submodules and
  # provides getHelper() method for finding and loading a tool-specific
  # helper (if there is one).
  module ToolHelperClassLoader
    # Finds and loads a tool-specific helper class, if present.
    def getHelper(helperType, *args)
      # File with tool-specific helper class (if any)
      helperFileName = "brl/genboree/tools/#{@toolIdStr}/#{@toolIdStr}#{helperType}Helper"
      # Name of tool-specific helper class:
      helperClassName = "#{@toolIdStr}#{helperType}Helper"
      helperClassName[0,1] = helperClassName[0,1].upcase
      # Name of instance variable which will hold instance of the tool-specific instance variable:
      helperInstanceVarName = "@#{helperType}Helper"
      helperInstanceVarName[1,1] = helperInstanceVarName[1,1].downcase
      # Try to require the tool-specific helper file and get the class [singleton object/constant]
      # . if fails, default to generic helper of the same type
      begin
        # try to require
        require helperFileName
        # get class itself
        helperClass = BRL::Genboree::Tools.const_get(helperClassName)
      rescue Exception => err # no helper class, use generic helper class
        $stderr.puts "DEBUG: (not necessarily an error...just no tool SPECIFIC helper class found).\n  Original exception message: #{err.message}"
        # ensure generic helper file has been required
        helperFileName = "brl/genboree/tools/workbench#{helperType}Helper"
        require helperFileName
        # get class itself
        helperClass = BRL::Genboree::Tools.const_get("Workbench#{helperType}Helper")
      end
      # Set the instance variable holding the helper class (e.g. @rulesHelperClass)
      self.instance_variable_set("#{helperInstanceVarName}Class", helperClass)
      # Set the instance variable hold the instance of the helper class (e.g. @rulesHelper)
      self.instance_variable_set(helperInstanceVarName, helperClass.new(@toolIdStr, @genbConf, @dbu, args))
      helperClassInstance = self.instance_variable_get(helperInstanceVarName)
      helperClassInstance.rackEnv = @req.env
      setApiUriHelpers(helperClassInstance, @req.env)
    end

    # Instantiates all api helper classes for child rules/job helpers to use
    # [+helperClassInstance+]
    # [+rackEnv+] rack env object
    # [+returns+] nil
    def setApiUriHelpers(helperClassInstance, rackEnv)
      # Grow this hash of reusable components to avoid excess instantiation
      reusableComponents = { :superuserApiDbrc => @superuserApiDbrc, :superuserDbDbrc => @superuserDbDbrc }
      # Group api helper
      helperClassInstance.grpApiHelper = BRL::Genboree::REST::Helpers::GroupApiUriHelper.new(@dbu, @genbConf, reusableComponents)
      helperClassInstance.grpApiHelper.rackEnv = rackEnv
      reusableComponents[:grpApiUriHelper] = helperClassInstance.grpApiHelper
      # Project api helper
      helperClassInstance.prjApiHelper = BRL::Genboree::REST::Helpers::ProjectApiUriHelper.new(@dbu, @genbConf, reusableComponents)
      helperClassInstance.prjApiHelper.rackEnv = rackEnv
      reusableComponents[:prjApiUriHelper] = helperClassInstance.dbApiHelper
      # Database api helper
      helperClassInstance.dbApiHelper = BRL::Genboree::REST::Helpers::DatabaseApiUriHelper.new(@dbu, @genbConf, reusableComponents)
      helperClassInstance.dbApiHelper.rackEnv = rackEnv
      reusableComponents[:dbApiUriHelper] = helperClassInstance.dbApiHelper
      # Track api helper
      helperClassInstance.trkApiHelper = BRL::Genboree::REST::Helpers::TrackApiUriHelper.new(@dbu, @genbConf, reusableComponents)
      helperClassInstance.trkApiHelper.rackEnv = rackEnv
      reusableComponents[:trkApiUriHelper] = helperClassInstance.trkApiHelper
      # Class api helper
      helperClassInstance.classApiHelper = BRL::Genboree::REST::Helpers::ClassApiUriHelper.new(@dbu, @genbConf, reusableComponents)
      helperClassInstance.classApiHelper.rackEnv = rackEnv
      # File api helper
      helperClassInstance.fileApiHelper = BRL::Genboree::REST::Helpers::FileApiUriHelper.new(@dbu, @genbConf, reusableComponents)
      helperClassInstance.fileApiHelper.rackEnv = rackEnv
      reusableComponents[:fileApiUriHelper] = helperClassInstance.fileApiHelper
      # Sample api helper
      helperClassInstance.sampleApiHelper = BRL::Genboree::REST::Helpers::SampleApiUriHelper.new(@dbu, @genbConf, reusableComponents)
      helperClassInstance.sampleApiHelper.rackEnv = rackEnv
      reusableComponents[:sampleApiUriHelper] = helperClassInstance.sampleApiHelper
      # SampleSet api helper
      helperClassInstance.sampleSetApiHelper = BRL::Genboree::REST::Helpers::SampleSetApiUriHelper.new(@dbu, @genbConf, reusableComponents)
      helperClassInstance.sampleSetApiHelper.rackEnv = rackEnv
      reusableComponents[:sampleSetApiUriHelper] = helperClassInstance.sampleSetApiHelper
      # Track Entity List api helper
      helperClassInstance.trackEntityListApiHelper = BRL::Genboree::REST::Helpers::TrackEntityListApiUriHelper.new(@dbu, @genbConf, reusableComponents)
      helperClassInstance.trackEntityListApiHelper.rackEnv = rackEnv
      reusableComponents[:trackEntityListApiUriHelper] = helperClassInstance.trackEntityListApiHelper
      # File Entity List api helper
      helperClassInstance.fileEntityListApiHelper = BRL::Genboree::REST::Helpers::FileEntityListApiUriHelper.new(@dbu, @genbConf, reusableComponents)
      helperClassInstance.fileEntityListApiHelper.rackEnv = rackEnv
      reusableComponents[:fileEntityListApiUriHelper] = helperClassInstance.fileEntityListApiHelper
    end

  end
end ; end ; end
