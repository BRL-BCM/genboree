#!/usr/bin/env ruby
require 'open3'
require 'stringio'
require 'brl/util/util'
require 'brl/genboree/abstract/resources/abstractStreamer'
require 'brl/genboree/seqRetriever'

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
  # For serving static files in chunks via API in a Rack-based web server stack
  # - especially binary and large files
  class FastaHandler < AbstractStreamer
    attr_accessor :groupName, :dbName, :chromNames, :from, :to
    attr_accessor :doAllUpper, :doAllLower, :doRevCompl

    def initialize(groupName, dbName, chromNames=nil, from=nil, to=nil, doAllUpper=false, doAllLower=false, doRevCompl=false)
      super()
      unless(self.class.method_defined?(:child_each))
        alias :child_each :each
        alias :each :parent_each
      end
      @groupName = groupName
      @dbName = dbName
      # setup the seqRetriever with these required fields
      @seqRetriever = BRL::Genboree::SeqRetriever.new()
      @seqRetriever.setupUserDb(@groupName, @dbName)
      # these will define the actual retrieval
      unless(chromNames.is_a?(Array) or chromNames.nil?)
        chromNames = [chromNames]
      end
      @chromNames = chromNames
      @from = (from.nil? ? nil : from.to_i)
      @to = (to.nil? ? nil : to.to_i)
      # set these options in the seqRetriever now -- enforce boolean here or thin may crash
      @seqRetriever.doAllUpper = !!doAllUpper
      @seqRetriever.doAllLower = !!doAllLower
      @seqRetriever.doRevCompl = !!doRevCompl
    end

    # Serve the sequence in FASTA chunks of size defined in the seqRetriever
    def each()
      if(@chromNames.nil?)
        # then give the whole genome
        @seqRetriever.yieldFastaSequenceForGenome(){ |chunk| yield chunk if(!chunk.empty? and !chunk.nil?)}
      elsif(@chromNames.length > 1)
        # then provide the whole chromosome sequence for each of the given chromosomes
        # from, to parameters in seqRetriever forced to nil since it is unlikely the user intended to
        # get the same range for multiple chromosomes
        @chromNames.each{ |chromName|
          yield @seqRetriever.makeDefline(chromName, nil, nil)
          @seqRetriever.yieldSequenceForRange() { |chunk| yield chunk if(!chunk.empty? and !chunk.nil?)}
        }
      else
        # then give a single chromosome with optional start and stop parameters
        chromName = @chromNames.first
        yield @seqRetriever.makeDefline(chromName, @from, @to)
        @seqRetriever.yieldSequenceForRange(){ |chunk| yield chunk if(!chunk.empty? and !chunk.nil?)}          
      end
    end
  end
end ; end ; end ; end  # module BRL ; module Genboree ; module Abstract ; module Resources
