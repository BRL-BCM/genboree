#!/usr/bin/env ruby
require 'thread'
require 'rack'
require 'brl/util/util'
require 'brl/genboree/abstract/resources/group'
require 'brl/genboree/abstract/resources/database'
require 'brl/genboree/abstract/resources/project'
require 'brl/genboree/abstract/resources/tracks'
require 'brl/genboree/abstract/resources/bioSamples'
require 'brl/genboree/rest/resources/genboreeResource'

#--
# Pre-declare namespace
module BRL ; module Genboree ; module Abstract ; module Resources
end ; end ; end ; end
# Because of misleading name ("Abstract" classes are something specific in OOP and Java,
# this has lead to confusion amongst newbies), I think this shorter Constant should
# be made available by all Abstract::Resources classes. Of course, we should only set
# the constant once, so we use const_defined?()...
Abstraction = BRL::Genboree::Abstract::Resources unless(Module.const_defined?(:Abstraction))
#++

module BRL ; module Genboree ; module Abstract ; module Resources
  # This class provides methods for managing tracks
  class EntityList
    # ------------------------------------------------------------------
    # CONSTANTS
    # ------------------------------------------------------------------
    ENTITY_TYPE_TO_TABLE_NAME = {
      'grps' => 'genboreegroup',
      'dbs' => 'refseq',
      'prjs' => 'projects',
      'grp' => 'genboreegroup',
      'db' => 'refseq',
      'prj' => 'projects',
      "trks" => "tracks",
      "files" => "files",
      "samples" => "bioSamples",     # The resource list table is sampleResourceList
      "bioSamples" => "bioSamples",  # DEPRECATED: There is no bioSamplesResourceList. The corresponding data would be in sampleResourceList.
      "sampleSets" => "sampleSets",
      "analyses" => "analyses",
      "experiments" => "experiments",
      "studies" => "studies",
      "runs" => "runs",
      "mixed" => "mixed"
    }

    # This table is correct for entity lists [only] as they are the first to supplant
    # old "bioSamples" with just "samples" in prep for doing away with old/ancient "samples" stuff
    ENTITY_TYPE_TO_ENTITYLIST_TABLE_NAME = {
      #'grps' => 'groups',
      #'dbs' => 'databases',
      #'prjs' => 'projects',
      #'grp' => 'genboreegroup',
      #'db' => 'refseq',
      #'prj' => 'projects',
      "trks" => "tracks",
      "files" => "files",
      "samples" => "samples",     # The resource list table is sampleResourceList
      #"bioSamples" => "samples",  # DEPRECATED: There is no bioSamplesResourceList. The corresponding data would be in sampleResourceList.
      "sampleSets" => "sampleSets",
      "analyses" => "analyses",
      "experiments" => "experiments",
      "studies" => "studies",
      "runs" => "runs",
      "mixed" => "mixed"
    }

    ENTITY_TYPE_TO_ENTITYLIST_TYPE = {
      'grp' => 'grps',
      'db' => 'dbs',
      'prj' => 'prjs',
      "trk" => "trks",
      "file" => "files",
      "sample" => "samples",     # The resource list table is sampleResourceList
      "bioSample" => "samples",  # DEPRECATED: There is no bioSamplesResourceList. The corresponding data would be in sampleResourceList.
      "sampleSet" => "sampleSets",
      "analysis" => "analyses",
      "experiment" => "experiments",
      "study" => "studies",
      "run" => "runs",
      "mixed" => "mixed"
    }

    ENTITY_TYPE_TO_ABSTRACTION_CLASS = {
      'grps' => BRL::Genboree::Abstract::Resources::Group,
      'grp' => BRL::Genboree::Abstract::Resources::Group,
      'dbs' => BRL::Genboree::Abstract::Resources::Database,
      'db' => BRL::Genboree::Abstract::Resources::Database,
      'prjs' => BRL::Genboree::Abstract::Resources::Project,
      'prj' => BRL::Genboree::Abstract::Resources::Project,
      "trks" => BRL::Genboree::Abstract::Resources::Tracks,
      "samples" => BRL::Genboree::Abstract::Resources::BioSamples,
      "bioSamples" => BRL::Genboree::Abstract::Resources::BioSamples
    }

    # Gets the types of entity lists in a given database.
    # - by default only returns those types (keys in ENTITY_TYPE_TO_TABLE_NAME)
    #   which are NON-empty in the database; but if all types are requested, whether
    #   empty or not, this becomes equivalent to asking for ENTITY_TYPE_TO_TABLE_NAME.keys
    # [+dbu+]           - Instance of +DBUtil+, ready to do DB work on appropriate user database.
    # [+onlyNonEmpty+]  - Only include types that are NON-empty (have 1+ entity lists) in the database
    # [+returns+]       - Array of entity types having entityLists in the database. See ENTITY_TYPE_TO_TABLE_NAME keys.
    def self.getEntityListTypes(dbu, onlyNonEmpty=true)
      retVal = nil
      if(onlyNonEmpty)  # then need to do some db queries
        retVal = []
        ENTITY_TYPE_TO_ENTITYLIST_TABLE_NAME.each_key { |entityType|
          tableBaseName = ENTITY_TYPE_TO_ENTITYLIST_TABLE_NAME[entityType]
          if(tableBaseName)
            rows = dbu.countResourceListNames(tableBaseName)
            if(rows and !rows.empty?)
              row  = rows.first
              retVal << entityType if(row and row['count'] > 0)
            end
          end
        }
      else # want all, regardless of empty or not
        retVal = ENTITY_TYPE_TO_ENTITYLIST_TABLE_NAME.keys
      end
      return retVal
    end # def getEntityListTypes(detailed=false)
  end # class EntityList
end ; end ; end ; end # module BRL ; module Genboree ; module Abstract ; module Resources
