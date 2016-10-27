#!/bin/env ruby

require 'brl/genboree/kb/helpers/abstractHelper'

module BRL ; module Genboree ; module KB ; module Helpers

  class DataDocHelper < AbstractHelper

    # @return [Array] the indices for the model documents in the models collection
    KB_CORE_INDICES =
    [

    ]

    def initialize(kbDatabase, collName)
      super(@kbDatabase)
      @coll = @kbDatabase.getCollection(collName)
    end

  end # class ModelsHelper
end ; end ; end ; end # module BRL ; module Genboree ; module KB ; module Helpers
