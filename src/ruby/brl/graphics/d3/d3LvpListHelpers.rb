#!/usr/bin/env ruby
require 'json'
require 'brl/util/util'

module BRL ; module Graphics ; module D3
  # Helper methods for working with D3 Label-Value list data structures--the kind
  #   used by D3 donut, pie, bar, etc charts.
  class D3LvpListHelpers
    # Goes through 2 D3 Label-Value pair lists and subtracts the values in the subtraction
    #   list from the totals in the first D3 LVP list.
    # @param [Array] totalsList List of D3 LVP nodes with the totals
    # @param [Array] subtractList The subtraction list--LVPs whose values to subtract from matching value in original
    # @param [Fixnum] Value to use when a partition has no value. Warning: D3 javascript may not be happy with null node values,
    #   so if you use nil you may need to do some cleanup after.
    # @return [Array<Hash>] A new D3 LVP list where the values for the labels are the totals minus the matching value in the subtraction list.
    def self.subtractD3LvpLists(totalsList, subtractList, missingValue=0)
      outputNodeList = []
      totalsList.each { |srcNode|
        srcLabel = srcNode[:label]
        srcVal = srcNode[:value]
        newVal = missingValue
        subtractList.each { |subNode|
          # if(subNode[:label] =~ /#{labelInSrcList}/) # Why regexp? Not clear; possible parochial reason or shortcut in orig context.
          if(subNode[:label] == srcLabel)
            subVal = subNode[:value]
            newVal = srcVal - subVal
            break
          end
        }
        outputNodeList << { :label => srcLabel, :value => newVal }
      }
      return outputNodeList
    end

    # Constructs a new D3 LVP list by computing the percentage using values from the
    #   parts (numerator) list divided by the values from the totals (denominator) list.
    # @param [Array<Hash>] totalsList List of D3 LVP nodes with the totals.
    # @param [Array<Hash>] partsList List of D3 LVP nodes with the parts of the totals, using the same labels.
    # @param [Array<Hash>] A new D3 LVP list where the values for the labels are the percentages.
    def self.percentageD3LvpLists(totalsList, partsList, missingVal=0)
      outputNodeList = []
      totalsList.each { |totalNode|
        totalLabel = totalNode["label"]
        totalVal = totalNode["value"]
        percentVal = missingVal
        partsList.each { |partNode|
          #if l2[:label] =~ /#{labelInList1}/ # Why regexp? Not clear; possible parochial reason or shortcut in orig context.
          if(partNode["label"] == totalLabel)
            partVal = partNode["value"]
            percentVal = partVal.to_f / totalVal.to_f * 100.0
            break
          end
        }
        outputNodeList << { "label" => totalLabel, "value" => percentVal }
      }
      return outputNodeList
    end
    
    # Constructs a new D3 LVP list by computing the percentage using values from the
    #   parts (numerator) list divided by the total value (denominator) of the list.
    # @param [Array<Hash>] partsList List of D3 LVP nodes with the labels.
    # @param [Array<Hash>] A new D3 LVP list where the values for the labels are the percentages of that list.
    def self.percentageD3LvpOneList(partsList, missingVal=0)
      outputNodeList = []
      totalValue = missingVal
      totalValue += sumValues(partsList)
      
      partsList.each { |partsNode|
        percentVal = missingVal
        totalLabel = partsNode["label"]
        partsValue = partsNode["value"]
        percentVal = partsValue.to_f / totalValue.to_f * 100.0
        outputNodeList << { "label" => totalLabel, "value" => percentVal }
      }
      return outputNodeList
    end
 
    # Creates a Stacked-Values d3 data structure from N input 1D (flat) D3 LVP type datasets. Can be
    #   suitable for stacked-bar type charts, especialy with @datasetsAreSubsets@ option, where stacking
    #   and computation is done based on labels.
    # @note For each D3 LVP type dataset in d3LvpLists, it will be merged into a data structure
    #   that can be given to d3.values() to prep it (hopefully unnecessarily) for use with d3.layout.stack()
    # @param [Array<Array>] d3LvpLists The array of D3 LVP type (flat) lists to stack.
    # @param [boolean] datasetsAreSubsets Set to true means that the numbers in the 2nd record are a subset of the ones in the
    #   1st record, etc (i.e. for the same x-category or label: 1st value > 2nd value > 3rd value...), and thus for d3
    #   we need to compute the subtractions.
    def self.stackFlatDatasets(d3LvpLists, datasetsAreSubsets=true)
      retVal = d3LvpLists.deep_clone
      # Do subset computation
      if(datasetsAreSubsets and retVal.size > 1)
        (retVal.size-2).downto(0) { |ii|
          # Subtract values of following row from current row's value to get stackable subset
          currRow = retVal[ii]
          subRow = retVal[ii+1]
          currRow.each { |currRec|
            subRec = subRow.find { |xx| xx['label'] == currRec['label'] }
            currRec['value'] -= subRec['value']
          }
        }
      end
      return retVal
    end

    def self.sumValues(d3LvpList)
      retVal = 0
      d3LvpList.each { |node|
        if(node.is_a?(Hash) and node['value'])
          retVal += node['value'].to_f
        end
      }
      return retVal
    end
    
    # Constructs a new D3 LVP list by merging labels based on common terms.
    # @param [Array<Hash>] partsList List of D3 LVP nodes with the labels.
    # @param [Array<Hash>] labelsGroup is a list of a group of labels and the groupName
    # labelsGroup hash should have the key "label" which is the groupName
    # and the key "originalLabel" which is a list of original labels
    # Example: labelGroups = [{"label"=>"Carcinoma", "originalLabel"=>["Colon Carcinoma", "Prostate Carcinoma", "Pancreatic Carcinoma", "colorectal cancer", "Gastric Cancer Pathologic TNM Finding v7"]}, {"label"=>"Preeclampsia", "originalLabel"=>["severe pre-eclampsia", "Chronic Maternal Hypertension with Superimposed Preeclampsia", "pre-eclampsia", "HELLP Syndrome"]}, {"label"=>"Hemorrhage", "originalLabel"=>["Intraventricular Brain Hemorrhage", "Subarachnoid Hemorrhage"]}]
    # If labelGroups is not specified, then the original labels are used
    # and the new list will have same number of nodes as original list, with an extra key called originalLabel
    # The new list will also have merged items - i.e. items array will have same number of entries as the originalLabel array
    # and the position of an entry in the originalLabel array should be same as the position of the items array
    # @param [Array<Hash>] A new D3 LVP list which has lesser number of nodes.
    def self.mergeSimilarLabels(partsList,labelGroups=[], missingVal=0)
      outputNodeList = []
      newGroupedList = {}
      addedLabel = []
        
      # Group labels and create a new node for each grouped label with combined values and items 
      labelGroups.each { |newGroup|
        groupLabel = newGroup["label"]            
        combinedValue = missingVal
        mergedItems = []
        originalLabels = []
        
        partsList.each { |partsNode|
          labelItems = []
          listLabel = partsNode["label"]          
          if(!addedLabel.include?(listLabel) && newGroup["originalLabel"].include?(listLabel))
            addedLabel << listLabel
            combinedValue += partsNode["value"]
            originalLabels << listLabel
            partsNode["items"].each {|item|
              item.each { |eachItem|
                labelItems << eachItem
              }  
            }
            if(!labelItems.empty?)
              mergedItems << labelItems
            else
              mergedItems << partsNode["items"]
            end  
            newGroupedList[groupLabel] = { "label" => groupLabel, "value" => combinedValue, "items" => mergedItems, "originalLabel" => originalLabels}
          end
        }  
      }
      # Add remaining nodes to the list if it is not part of the addedLabel list
      partsList.each { |partsNode|
        listLabel = partsNode["label"]
        labelItems = []
        if(!addedLabel.include?(listLabel))
          partsNode["items"].each {|item|
              item.each { |eachItem|
                labelItems << eachItem
              }  
          }
          newGroupedList[listLabel] = { "label" => listLabel, "value" => partsNode["value"], "items" => [labelItems], "originalLabel" => [listLabel] }
        end
      }
      
      outputNodeList = newGroupedList.values
      return outputNodeList
    end
    
  end
end ; end ; end
