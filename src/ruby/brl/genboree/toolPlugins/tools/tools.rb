# Matthew Linnell
# January 11th, 2006
#-------------------------------------------------------------------------------
# Home of the analysis mixins.  This is where you plugin the analysis tools
# so they can be loaded up by the main Pattern Discovery Wizard script
#-------------------------------------------------------------------------------
require 'brl/genboree/toolPlugins/tools/primer3/Primer3Tool'
require 'brl/genboree/toolPlugins/tools/tiler/tilerTool'
require 'brl/genboree/toolPlugins/tools/nameSelector/nameSelectorTool'
require 'brl/genboree/toolPlugins/tools/hgscPrimerDesign/hgscPrimerDesignTool'
require 'brl/genboree/toolPlugins/tools/lffSelector/lffSelectorTool'
require 'brl/genboree/toolPlugins/tools/flanking/flankedTool'
require 'brl/genboree/toolPlugins/tools/attributeLifter/attributeLifterTool'
require 'brl/genboree/toolPlugins/tools/segmentation/segmentationTool'
require 'brl/genboree/toolPlugins/tools/trackCopier/trackCopierTool'
require 'brl/genboree/toolPlugins/tools/sampleSelector/sampleSelectorTool'
#require 'brl/genboree/toolPlugins/tools/winnow/winnowTool'

module BRL
  module Genboree
    module ToolPlugins
      # CONSTANTS
      RUBY_APP = '/usr/local/brl/local/bin/ruby'
      LFF_TILER_APP = '/usr/local/brl/local/bin/lffTiler.rb'  # Tiler App
      LFF_NAMESELECTOR_APP = '/usr/local/brl/local/bin/lffNameSelector.rb' # Name Selector App
      LFF_SORTER_APP = '/usr/local/brl/local/bin/lffSorter.rb' # LFF Sorter App
      LFF_SELECTOR_APP = '/usr/local/brl/local/bin/lffRuleSelector.rb' # LFF Rule-based Selector App
      WINNOW_APP = '/usr/local/brl/local/bin/winnow.rb'

      module Tools
          #---------------------------------------------------------------------------
          # * *Function*: Provies a list of available analysese.  Add tools to this method to active automated command line validation and automated listings of available tools.
          #
          # * *Usage*   : <tt> BRL::ToolPlugins::Tools.list() </tt>
          # * *Args*    :
          #   - +none+ ->
          # * *Returns* :
          #   - +Hash+ -> A Hash of available tools and their corresponding description
          # * *Throws* :
          #   - +none+
          #---------------------------------------------------------------------------
          def self.list()
              return  {
                        :lffSelector        =>  BRL::Genboree::ToolPlugins::Tools::LffSelectorTool::LffSelectorClass,
                        :primer3            =>  BRL::Genboree::ToolPlugins::Tools::Primer3::Primer3Tool,
                        :tiler              =>  BRL::Genboree::ToolPlugins::Tools::TilerTool::TilerClass,
                        :nameSelector       =>  BRL::Genboree::ToolPlugins::Tools::NameSelectorTool::NameSelectorClass,
                        :sampleSelector     =>  BRL::Genboree::ToolPlugins::Tools::SampleSelectorTool::SampleSelectorClass,
                        :flankedDetector    =>  BRL::Genboree::ToolPlugins::Tools::FlankedDetectorTool::FlankedDetectorClass,
                        :attributeLifter    =>  BRL::Genboree::ToolPlugins::Tools::AttributeLifterTool::AttributeLifterClass,
                        :trackCopier        =>  BRL::Genboree::ToolPlugins::Tools::TrackCopierTool::TrackCopierClass,
                        :segmentation       =>  BRL::Genboree::ToolPlugins::Tools::SegmentationTool::SegmentationClass
                        # :winnow              =>  BRL::Genboree::ToolPlugins::Tools::WinnowTool::WinnowClass
                        # :hgscPrimerDesign   =>  BRL::Genboree::ToolPlugins::Tools::HgscPrimerDesignTool::HgscPrimerDesignClass
                      }
          end

          def self.order()
            return  [
                      :lffSelector,
                      :tiler,
                      :primer3,
                      :nameSelector,
                      :flankedDetector,
                      :attributeLifter,
                      :trackCopier,
                      :segmentation,
                      :sampleSelector
                      # :winnow
                      # :hgscPrimerDesign
                    ]
          end
        end
    end
  end
end
