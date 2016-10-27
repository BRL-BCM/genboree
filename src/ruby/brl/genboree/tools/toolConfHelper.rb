#!/usr/bin/env ruby

require 'brl/util/util'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/tools/toolConf'

module BRL ; module Genboree ; module Tools
  # Simple methods which operate on ToolConf.
  # @note Intended as MIX-IN instance methods to classes that have @@tooldIdStr@ and @@toolConf@ accessors avaialble!
  # @note Module method versions also available for other (non-mix-in) scenarios. i.e. @BRL::Genboree::Tools::ToolConfHelper.getUiConfigValue(...)@
  module ToolConfHelper

    # ------------------------------------------------------------------
    # PUBLIC HELPER METHODS (class & module)
    # ------------------------------------------------------------------

    # Get the value for a specific field in the ui conf.
    # (Convenience method to help get rid of old TOOL_* constants)
    # @param [String] property The name of the property in the 'ui' section of the tool's config file for which you want the value
    # @return [Object] the value for the property from the 'ui' section of the tool's config file.
    def getUiConfigValue(property)
      return BRL::Genboree::Tools::ToolConfHelper.getUiConfigValue(property, @toolIdStr, @toolConf)
    end

    # Get the value for a specific field in the ui conf for the indicated tool
    # (Convenience method to help get rid of old TOOL_* constants)
    # @param [String] property The name of the property in the 'ui' section of the tool's config file for which you want the value
    # @param [String] toolIdStr The tool id for the tool you want the value for.
    # @return [Object] the value for the property from the 'ui' section of the tool's config file.
    def self.getUiConfigValue(property, toolIdStr, toolConf=nil)
      retVal = nil
      unless(toolConf)
        toolConf = BRL::Genboree::Tools::ToolConf.new(toolIdStr)
      end
      retVal = toolConf.getSetting('ui', property)
      return retVal
    end

    # Get the value for a specific field in the info conf.
    # (Convenience method to help get rid of old TOOL_* constants)
    # @param [String] property The name of the property in the 'info' section of the tool's config file for which you want the value
    # @return [Object] the value for the property from the 'info' section of the tool's config file.
    def getInfoConfigValue(property)
      return BRL::Genboree::Tools::ToolConfHelper.getInfoConfigValue(property, @toolIdStr, @toolConf)
    end

    # Get the value for a specific field in the info conf for the indicated tool
    # (Convenience method to help get rid of old TOOL_* constants)
    # @param [String] property The name of the property in the 'info' section of the tool's config file for which you want the value
    # @param [String] toolIdStr The tool id for the tool you want the value for.
    # @return [Object] the value for the property from the 'info' section of the tool's config file.
    def self.getInfoConfigValue(property, toolIdStr, toolConf=nil)
      retVal = nil
      unless(toolConf)
        toolConf = BRL::Genboree::Tools::ToolConf.new(toolIdStr)
      end
      retVal = toolConf.getSetting('info', property)
      return retVal
    end
  end # module ToolConfHelper
end ; end ; end # module BRL ; module Genboree ; module Tools
