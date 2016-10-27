#!/usr/bin/env ruby
$stderr.puts "RUBY VERSION: #{RUBY_VERSION}"
# For the Helper modules within ActionView::Helpers::
require 'action_view'
require 'brl/util/util'
require 'brl/activeSupport/activeSupport'

module BRL ; module Genboree ; module Tools
  # Adds core helpers from ActiveView::Helpers:: submodules and
  # provides getHelper() method for finding and loading a tool-specific
  # helper (if there is one).
  module HelperExtender
    CORE_ACTIVEVIEW_HELPERS = [
      ActionView::Helpers::AssetTagHelper,
      ActionView::Helpers::DateHelper,
      ActionView::Helpers::FormHelper,
      ActionView::Helpers::FormOptionsHelper,
      ActionView::Helpers::FormTagHelper,
      ActionView::Helpers::JavaScriptHelper,
      ActionView::Helpers::NumberHelper,
      ActionView::Helpers::SanitizeHelper,
      ActionView::Helpers::TagHelper,
      ActionView::Helpers::TextHelper,
      ActionView::Helpers::UrlHelper
    ]

    # When a class extends this module, it will ensure that class is also
    # extended with key modules in ActiveView::Helpers:: modules
    # (i.e. the ones listed in CORE_ACTIVEVIEW_HELPERS).
    def self.extended(extender)
      CORE_ACTIVEVIEW_HELPERS.each { |helperModule|
        extender.extend(helperModule)
      }
      BRL::ActiveSupport.restoreJsonMethods()
    end
  end
end ; end ; end
