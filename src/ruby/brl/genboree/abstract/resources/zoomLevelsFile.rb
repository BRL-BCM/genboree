#!/usr/bin/env ruby

require 'brl/genboree/abstract/resources/annotationFile'

# This class is used to get a bed file from the database
# write it to a file on disk

module BRL ; module Genboree ; module Abstract ; module Resources


  class ZoomLevelsFile < AnnotationFile

    def initialize(dbu, fileName=nil, showTrackHead=false, options={})
      super(dbu, fileName)
      @hdhvType = 'zoomLevels'
    end


  end

end ; end ; end ; end
