#!/usr/bin/env ruby
require 'json'
require 'brl/util/util'
require 'brl/graphics/d3/d3LvpListHelpers'
require 'brl/graphics/d3/d3HierarchyHelpers'

module BRL ; module Genboree ; module KB ; module Graphics ; module D3
  # KB=>D3 converter helper class
  class KbTransformConverter
    attr_accessor :srcTransform

    # CONSTRUCTOR. Read transform json from file.
    # @param [String] Path to file containing transform output JSON.
    # @return [KbTransformConverter]
    def self.from_file(transformFilePath)
      jsonStr = File.read(transformFilePath)
      return self.from_string(jsonStr)
    end

    # CONSTRUCTOR. Transform JSON string provided.
    # @param [String] Transform output as JSON.
    # @return [KbTransformConverter]
    def self.from_string(transformJsonStr)
      parsedJson = JSON.parse(transformJsonStr)
      return self.new(parsedJson)
    end

    # CONSTRUCTOR.
    # @param [Hash] The source transform output (as nested Hash data structure) to make D3 data structures from.
    # @return [KbTransformConverter]
    def initialize(srcTransform)
      raise "ERROR: Sanity check failed. Transform doesn't appear to be a Hash-based nested structure with a root key of 'Data'." unless(srcTransform and srcTransform['Data'].is_a?(Array) and !srcTransform['Data'].empty?)
      @srcTransform = srcTransform
    end

    # Clean up the n-Dimensional partition "junk" entries (empty partitions etc. Generally gets rid of
    #   cruft and empty partitions only present for programmatic reasons not actual data presence reasons.
    # @param [Array<Hash>] The transform data structure to clean, or for internal recursion the part of the transform to clean.
    #   Generally just call with no argument so it operates on @srcTransform.
    def cleanPartData(transform=@srcTransform)
      if(transform == @srcTransform) # going to be doing deletes etc, make a copy to prevent messing with outside usage of data structure
        @srcTransform = @srcTransform.deep_clone
        transform = @srcTransform['Data']
      end
      transform.each { |partition|
        if(partition['data'].is_a?(Array) and !partition['data'].empty?)
          cleanPartData(partition['data'])
        else
          partition.delete('data')
        end
        if(!partition['cell'].is_a?(Hash) or partition['cell'].empty? or !partition['cell']['value'])
          partition.delete('cell')
        end
      }
      transform.delete_if { |partition| ( (!partition['data'] or partition['data'].empty?) and !partition['cell']) }
      return transform
    end

    # Alternative clean up of the n-Dimensional partition "junk" entries (empty partitions etc. If a partition
    #  has an actual 'cell' but the cell has no value, then the cell is given the default value. Partitions with no
    #  cells are still removed as in {#cleanPartData}.
    # @param [Object] defaultValue The default value for cells that are present in the transform but which have no
    #   value.
    # @param [Array<Hash>] The transform data structure to clean, or for internal recursion the part of the transform to clean.
    #
    def cleanPartDataKeepNoVal(defaultValue=0, transform=@srcTransform)
      if(transform == @srcTransform) # going to be doing deletes etc, make a copy to prevent messing with outside usage of data structure
        @srcTransform = @srcTransform.deep_clone
        transform = @srcTransform['Data']
      end
      transform.each { |transform|
        if(transform['data'].is_a?(Array) and !transform['data'].empty?)
          cleanPartDataKeepNoVal(transform['data'])
        else
          transform.delete('data')
        end
        if(transform['cell'].is_a?(Hash) and transform['cell'].key?('value'))
          transform['cell']['value'] = defaultValue unless(transform['cell']['value'])
        else
          transform.delete('cell')
        end
      }
      srcNodeList.delete_if { |transform| ( (!transform['data'] or transform['data'].empty?) and !transform['cell']) }
      return transform
    end

    # 1D partition => Label-Value pairs D3 (i.e. for donut/pie/bar chart)
    # - Partition name is the D3 node label and the cell.value is the D3 node value
    # The metadata.subjects array is the itemList nnode value
    # @param [Fixnum] Value to use when a partition has no value. Warning: D3 javascript may not be happy with null node values,
    #   so if you use nil you may need to do some cleanup after.
    # @param [Array,nil] Optional existing D3 node array. Generally nil (for internal use)
    # @param [String,nil] Optional current node label, used to build path-like labels. Generally nil.
    # @return [Array] The flat D3 Label-Value array.
    def to_d3Lvp(missingValue=0, currLabel=nil)
      outputList = []
      @srcTransform['Data'].each { |partition|
        name = partition['name']
        label = (currLabel ? "#{currLabel}.#{name}" : name)
        if(partition['cell'].is_a?(Hash) and partition['cell']['value']) # If this partition has a value, extract it.
          value = partition['cell']['value']
          itemList = partition['cell']['metadata']['subjects']
        else
          value = missingValue # Else no value, so use missingValue
        end
        outputList << { 'label' => label, 'value' => value, 'items' => itemList }
      }
      return outputList
    end

    # 1D partition => Label-Value pairs D3 (i.e. for donut/pie/bar charts), but
    #   SUM/ADD the individual 'subjects' found for the cell.metadata.subjects
    #   to get the D3 node value.
    # @note Obviously the 'subjects' must be number-like values and not names or something.
    #   Will be cast via String#to_f.
    # @note If there are no such subject values (or even cell) for a given partition,
    #   It will be given the @missingValue@ value.
    # @param (see #to_d3Lvp)
    # @return [Array] The flat D3 Label-Value array.
    def to_d3LvpSumSubjects(missingValue=0, currLabel=nil)
      outputList = []
      @srcTransform['Data'].each { |partition|
        name = partition['name']
        label = (currLabel ? "#{currLabel}.#{name}" : name)
        value = missingValue
        cell = partition['cell']
        if(cell.is_a?(Hash) and !cell.empty?)
          metadata = cell['metadata']
          if(metadata.is_a?(Hash) and !metadata.empty?)
            subjects = metadata['subjects']
            if(subjects.is_a?(Array) and !subjects.empty?)
              subjects.each { |sub|
                sub.each { |vals|
                  value += vals.to_f
                }
              }
            end
          end
        end
        outputList << { 'label' => label, 'value' => value }
      }
      return outputList      
    end

    # 1D partition => Label-Value pairs D3 (i.e. for donut/pie/bar charts), but
    #   SUM/ADD the individual 'subjects' found for the cell.metadata.subjects
    #   to get the D3 node value, if subject value matches a given matchString.
    # @note If there are no such subject values (or even cell) for a given partition,
    #   It will be given the @missingValue@ value.
    # @param (see #to_d3Lvp)
    # @return [Array<Hash>] A new D3 LVP list where the values for the labels are the totals of values that match the matchString in the list.
    def to_d3LvpSumSubjectsMatchVal(matchString=nil, currLabel=nil, missingValue=0)
      outputList = []
      @srcTransform['Data'].each { |partition|
        name = partition['name']
        label = (currLabel ? "#{currLabel}.#{name}" : name)
        matchValTotal = missingValue
        cell = partition['cell']
        if(cell.is_a?(Hash) and !cell.empty?)
          metadata = cell['metadata']
          if(metadata.is_a?(Hash) and !metadata.empty?)
            subjects = metadata['subjects']
            if(subjects.is_a?(Array) and !subjects.empty?)
              subjects.each { |sub|
                sub.each { |vals|
                  if(vals == matchString)
                    matchValTotal += 1
                  end
                }
              }
            end
          end
        end
        outputList << { 'label' => label, 'value' => matchValTotal }
      }
      return outputList
    end

    # n-Dimensional partitioning => Hierarchical D3 tree for Sunburst, Dendrogram, Pack, etc.
    # @param [Hash] The partitioned transform to convert or piece of transform (for internal recursion).
    #   Generally do not set.
    # @return [Hash] A D3 type hierarchical tree data structure.
    def to_d3Hierarchical(transform=@srcTransform)
      # If at very root of transform, need to start at 'Data' field
      if(transform == @srcTransform)
        transform = @srcTransform['Data']
      end
      d3Node = { 'children' => [] }
      transform.each { |partition|
        if( (partition['cell'].is_a?(Hash) and partition['cell']['value']) or partition['data'].is_a?(Array) )
          if(partition['cell'].is_a?(Hash))
            cell = partition['cell']
            if(cell['value'])
              d3ChildNode = { 'name' => partition['name'] }
              d3ChildNode['size'] = cell['value']
            end
          end
          if(partition['data'].is_a?(Array))
            d3ChildNode = to_d3Hierarchical(partition['data'])
            d3ChildNode['name'] = partition['name']
          end
          d3Node['children'] << d3ChildNode
        end
      }
      return d3Node
    end

    # Grant total of ALL 'subjects' values. Can choose to return the grand total (Float)
    #   or a D3 LVP node which you can tack onto an existing D3 LVP node list or something.
    #   If you choose the latter, you can customize the label of this D3 LVP node.
    # @note Obviously the 'subjects' must be number-like values and not names or something.
    #   Will be cast via String#to_f.
    # @note If there are no such subject values (or even cell) for a given partition,
    #   It will be given the @missingValue@ value.
    # @param [Fixnum] Value to use when a partition has no value. Warning: D3 javascript may not be happy with null node values,
    #   so if you use nil you may need to do some cleanup after.
    # @param [boolean] returnNode Set to true if you want a D3 LVP type node returned not just the raw grand total.
    # @param [String] label If @returnNode=true@ then can use this label for the returned node rather than default of "Total".
    # @return [Float,Hash] The grand total as a number or a D3 LVP type node depending on @returnNode@.
    def sumOfAllSubjects(missingValue=0, returnNode=false, label="Total")
      value = missingValue
      @srcTransform['Data'].each { |node|
        cell = node['cell']
        if(cell.is_a?(Hash) and !cell.empty?)
          metadata = cell['metadata']
          if(metadata.is_a?(Hash) and !metadata.empty?)
            subjects = metadata['subjects']
            if(subjects.is_a?(Array) and !subjects.empty?)
              subjects.each { |sub|
                sub.each { |vals|
                  value += vals.to_i
                }
              }
            end
          end
        end
      }
      if(returnNode)
        retVal = { 'label' => label, 'value' => value }
      else
        retVal = value
      end
      return retVal
    end
  end
end ; end ; end ; end ; end # module BRL ; module Genboree ; module KB ; module Graphics ; module D3
