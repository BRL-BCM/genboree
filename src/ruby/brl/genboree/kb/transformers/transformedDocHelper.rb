#!/usr/bin/env ruby

module BRL; module Genboree; module KB; module Transformers
  class TransformedDocHelper

    # Count the number of leaves rooted at the subtree within dataTree specified by path
    # @param [Hash] dataTree a json-like tree data structure
    # @param [String, Array] path either an opts[:delim] delimited string providing a mongo-style  
    #   path to the subtree root in dataTree or an array of such tokens
    # @param [Hash] opts
    #   :dfsKey [String, Symbol] the name of the key in nodes of the tree where (sum, count) 
    #   information can be found, provided by e.g. aggregateLeaves
    #   :nameKey [String, Symbol] the name of the key where the name of the node can be found
    #   :rootChildrenKey [String, Symbol] the name of the key where the children of the root node
    #     can be found
    #   :intChildrenKey [String, Symbol] the name of the key where the children of internal nodes
    #     can be found
    #   :delim [String] the delimiter of path if it is given as a String
    # @return [Symbol, Fixnum] either the count of leaves for the tree rooted at the path-specified
    #   subtree or a Symbol indicating the type of failure; symbols include
    #     :no_path - the path provided by the path variable is invalid
    #     :no_count - could not calculate count probably due to recursion error or missing keys
    #       in the dataTree
    # @note dataTree will be modified in place if opts[:tryCount] is set
    def self.getCountForPath(dataTree, path, opts={})
      supOpts = { :dfsKey => "count", :nameKey => "name", :rootChildrenKey => "Data", 
                  :intChildrenKey => "data", :delim => ".", :tryCount => true,
                  :op => "count"
                }
      opts = supOpts.merge(opts)
      retVal = nil
      if(path.is_a?(String))
        #path = path.split(opts[:delim])
        path = path.gsub(/\\\./, "\v").split('.').map{ |xx| xx.gsub(/\v/, '.') }
      end
      pi = 0
      dataElem = dataTree
      childrenKey = opts[:rootChildrenKey]
      if(dataElem.nil?)
        retVal = :no_path
      else
        while(pi < path.size)
          pathElem = path[pi]
          #dataElem = dataElem[childrenKey].find { |node| node[opts[:nameKey]] == pathElem }
          dataElem = (dataElem[childrenKey] and dataElem[childrenKey].find { |node| node[opts[:nameKey]] == pathElem })
          if(dataElem.nil?)
            retVal = :no_path
            break
          else
            count = dataElem[opts[:dfsKey]]
            if(count.nil?)
              retVal = :no_count
              break
            else
              retVal = dataElem[opts[:dfsKey]]
            end
          end
          pi += 1
          childrenKey = opts[:intChildrenKey]
        end
      end

      if(retVal == :no_count and opts[:tryCount])
        # then try to fix by modifying dataTree ourselves
        opts[:tryCount] = false
        totalCount = self.aggregateLeaves(dataTree, opts)
        retVal = self.getCountForPath(dataTree, path, opts) 
      end

      return retVal
    end

    # Modify dataTree structure with an operation on the leaves in the subtree rooted at a given
    #   node of the tree
    # @param [Hash] dataTree json-like data structure
    # @param [Hash] opts options hash with the following keys supported
    #   [String, Symbol] :dfsKey the name of the key added to nodes containing the count of
    #     leaf nodes contained in the subtree rooted at a given node
    #   [String, Symbol] :childrenKey the name of the key where the children of this node can be found,
    #     must respond to :each to iterate over children
    #   [String, Symbol] :rootKey the name of the key for the root of the tree in dataTree
    #   [String, Symbol] :nameKey the name of the key for the name of nodes; path specifies values found
    #     at this nameKey
    #   [String, Symbol] :leafKey the name of the key for the "satellite" data of a leaf node
    #   [String, Symbol] :valueKey the name of the key within the satellite data Hash specified by leafKey
    #     which contains the value we want to sum
    #   [String] :op the aggregating operation to perform; supported operations:
    #     "count" - count the number of leaves for a subtree rooted at a given node
    #     "sum" - sum the :valueKey for leaves of a subtree rooted at a given node
    # @return [Hash] the modified dataTree
    # @todo valueKey only applies to sumLeavesByPath
    def self.aggregateLeaves(dataTree, opts={})
      supOpts = { :dfsKey => "count", :rootChildrenKey => "Data", :intChildrenKey => "data", 
                   :nameKey => "name", :leafKey => "cell", :valueKey => "value",
                   :op => "count" }
      opts = supOpts.merge(opts)
      retVal = 0
      children = dataTree[opts[:rootChildrenKey]]
      children.each { |child|
        dfsCount = dfs(child, depth=0, opts)
        if(dfsCount.nil?)
          retVal = nil
          break
        else
          retVal += dfs(child, depth=0, opts)
        end
      }
      return retVal
    end

    # Perform recursion for aggregateLeaves
    # @param [Hash] node a node in a tree to do depth-first traversal on
    # @param [Fixnum] depth the current traversal depth (to prevent too deep of recursion)
    # @param [Hash] opts @see aggregateLeaves
    def self.dfs(node, depth=0, opts={})
      supOpts = { :dfsKey => "count", :intChildrenKey => "data", :leafKey => "cell", 
                  :valueKey => "value", :maxDepth => 10, :op => "count" }
      opts = supOpts.merge(opts)
      retVal = 0
      retArray = []
      depth += 1
      if(node.key?(opts[:leafKey]))
        value = node[opts[:leafKey]][opts[:valueKey]]
        leafVal = nil
        if(opts[:op] == "sum" or opts[:op] == "value")
          leafVal = (value.nil? ? 0 : value.to_i)
        else
          # default count
          $stderr.debugPuts(__FILE__, __method__, "WARNING", "Unrecognized operation #{opts[:op]}, defaulting to \"count\"") unless(opts[:op] == "count")
          leafVal = (value.nil? ? 0 : 1)
        end
        node[opts[:dfsKey]] = leafVal
        retVal = leafVal
      else
        if(depth < opts[:maxDepth])
          node[opts[:intChildrenKey]].each{ |node2|
            dfsCount = dfs(node2, depth, opts)
            if(dfsCount.nil?)
              retVal = nil
              break
            else
              if(opts[:op] == "value")
                retArray << dfsCount
              else
                retVal += dfsCount
              end
            end
          }
          node[opts[:dfsKey]] = retVal
          retVal = retArray if(opts[:op] == "value")
        else
          $stderr.debugPuts(__FILE__, __method__, "ERROR", "Max depth #{opts[:maxDepth]} reached")
          retVal = nil
        end
      end
      return retVal
    end

    # @param [Hash] dataTree a json-like tree data structure
    # @param [String] path either an opts[:delim] delimited string providing a mongo-style  
    #   path to the subtree root in dataTree or an array of such tokens
    # @param [Hash, String, Array] valToAdd value of @opts[:addKey]@ to be set at the node @path@
    # @param [Hash] opts options hash with the following keys supported
    #   :dfsKey [String, Symbol] the name of the key in nodes of the tree where (sum, count) 
    #   information can be found, provided by e.g. aggregateLeaves
    #   :nameKey [String, Symbol] the name of the key where the name of the node can be found
    #   :rootChildrenKey [String, Symbol] the name of the key where the children of the root node
    #     can be found
    #   :intChildrenKey [String, Symbol] the name of the key where the children of internal nodes
    #     can be found
    #   :delim [String] the delimiter of path if it is given as a String
    #   :addKey [String, Symbol] the name of the key that is to be added or set for the @path@
    # @return [Symbol] Symbol indicating the type of failure or success ; symbols include
    #     :no_path - the path provided by the path variable is invalid
    #     :no_key - the name of the key provided via :addKey does not exist. Applicable only for
    #     leaf node, :leafKey.     
    #     :added - @valtoAdd@ successfully added.
    def self.addFieldToPath(dataTree, path, valToAdd, append=true, opts={})
      supOpts = { :dfsKey => "count", :nameKey => "name", :rootChildrenKey => "Data", 
                  :leafKey => "cell", :intChildrenKey => "data", :delim => ".", :addKey => nil,
                  :valueKey => "value", :otherKey => nil, :metKey=> nil
                }
      opts = supOpts.merge(opts)
      retVal = :added
      if(path.is_a?(String))
        #path = path.split(opts[:delim])
        path = path.gsub(/\\\./, "\v").split('.').map{ |xx| xx.gsub(/\v/, '.') }
      end
      pi = 0
      dataElem = dataTree
      childrenKey = opts[:rootChildrenKey]
      if(dataElem.nil?)
        retVal = :no_path
      else
        while(pi < path.size)
          pathElem = path[pi]
          #dataElem = dataElem[childrenKey].find { |node| node[opts[:nameKey]] == pathElem }
          dataElem = (dataElem[childrenKey] and dataElem[childrenKey].find { |node| node[opts[:nameKey]] == pathElem })
          if(dataElem.nil?)
            retVal = :no_path
            break
          end
          pi += 1
          childrenKey = opts[:intChildrenKey]
        end
      end
      #$stderr.puts "DATA ELEM: #{dataElem.inspect}"
      unless(dataElem.nil?)
        unless(opts[:addKey].nil?)
          #if value is to be added to the cell key, make sure that it is a leaf node
          if(opts[:addKey] == opts[:leafKey])
            # key is 'value' cell => {'value' => nil}
            if(valToAdd.is_a?(Hash) and valToAdd.key?(opts[:valueKey]))
              dataElem.key?(opts[:leafKey]) ? (dataElem[opts[:addKey]] = valToAdd) : retVal = :no_path
            else
              if(dataElem.key?(opts[:leafKey]))
                if(dataElem[opts[:leafKey]].key?(opts[:otherKey]))
                  if(dataElem[opts[:addKey]][opts[:otherKey]].key?(opts[:metKey]))
                    dataElem[opts[:addKey]][opts[:otherKey]][opts[:metKey]] <<  valToAdd
                    dataElem[opts[:addKey]][opts[:otherKey]][opts[:metKey]].flatten!
                  else
                    dataElem[opts[:addKey]][opts[:otherKey]][opts[:metKey]] = valToAdd
                  end
                else
                  dataElem[opts[:addKey]][opts[:otherKey]] = {}
                  dataElem[opts[:addKey]][opts[:otherKey]][opts[:metKey]] =  valToAdd
                end
              else
                retVal = :no_path
              end
            end
          elsif(opts[:addKey] == opts[:intChildrenKey])
            if(append)
              dataElem[opts[:addKey]] << valToAdd
            else
              dataElem[opts[:addKey]].unshift(valToAdd)
            end
          else
            if(dataElem.key?(opts[:addKey]))
              if(dataElem[opts[:addKey]].key?([opts[:metKey]]))
                dataElem[opts[:addKey]][opts[:metKey]] << valToAdd
              else
                dataElem[opts[:addKey]][opts[:metKey]] = valToAdd
              end
            else
              #$stderr.puts "DATAEME: #{dataElem.inspect}"
              dataElem[opts[:addKey]] = {}
              dataElem[opts[:addKey]][opts[:metKey]] = valToAdd
            end
          end
        else
          retVal = :no_key
        end
      end
        
      return retVal       
    end


    # @param [Hash] dataTree a json-like tree data structure
    # @param [String] path either an opts[:delim] delimited string providing a mongo-style  
    #   path to the subtree root in dataTree or an array of such tokens
    # @param [Hash] opts options hash with the following keys supported
    #   :dfsKey [String, Symbol] the name of the key in nodes of the tree where (sum, count) 
    #   information can be found, provided by e.g. aggregateLeaves
    #   :nameKey [String, Symbol] the name of the key where the name of the node can be found
    #   :rootChildrenKey [String, Symbol] the name of the key where the children of the root node
    #     can be found
    #   :intChildrenKey [String, Symbol] the name of the key where the children of internal nodes
    #     can be found
    #   :delim [String] the delimiter of path if it is given as a String
    #   :getValueKey [String, Symbol] the name of the key from where the value is returned
    # @return [Symbol] Symbol indicating the type of failure or success ; symbols include
    #     :no_path - the path provided by the path variable is invalid
    #     :no_key - the name of the key provided via :addKey does not exist. Applicable only for
    #     leaf node, :leafKey.     
    #     :added - @valtoAdd@ successfully added.
    def self.getValFromPath(dataTree, path, opts={})
      supOpts = { :dfsKey => "count", :nameKey => "name", :rootChildrenKey => "Data",
                  :leafKey => "cell", :intChildrenKey => "data", :delim => ".", :getValueKey => nil
                }
      opts = supOpts.merge(opts)
      retVal = :retrieved
      if(opts[:getValueKey] == opts[:leafKey])
        if(path.is_a?(String))
          #path = path.split(opts[:delim])
          path = path.gsub(/\\\./, "\v").split('.').map{ |xx| xx.gsub(/\v/, '.') }
        end
        pi = 0
        dataElem = dataTree
        childrenKey = opts[:rootChildrenKey]
        if(dataElem.nil?)
          retVal = :no_path
        else
          while(pi < path.size)
            pathElem = path[pi]
            #dataElem = dataElem[childrenKey].find { |node| node[opts[:nameKey]] == pathElem }
            dataElem = (dataElem[childrenKey] and dataElem[childrenKey].find { |node| node[opts[:nameKey]] == pathElem })
            if(dataElem.nil?)
              retVal = :no_path
              break
            end
            pi += 1
            childrenKey = opts[:intChildrenKey]
          end
        end
        #$stderr.puts "DATA ELEM: #{dataElem.inspect}"
        unless(dataElem.nil?)
          #if value is to be retrieved from the cell key, make sure that it is a leaf node
          if(opts[:getValueKey] == opts[:leafKey])
            dataElem.key?(opts[:leafKey]) ? (retVal = dataElem[opts[:getValueKey]]['value']) : retVal = :no_path
          else
            retVal = :no_valueKey
          end
        end
      else
        retVal = :invalid_value_path
      end  
      return retVal
    end

    # Returns a new column or a row from the dataTree.
    # Performs the operation - sum, average, max, min, count on new data type
    # @param [Hash] dataTree a json-like tree data structure
    # @param [String] type the data type 'row' or 'col'
    # @param [Fixnum] depth the current traversal depth (to prevent too deep of recursion)
    # @param [Hash] opts options hash with the following keys supported
    #   :dfsKey [String, Symbol] the name of the key in nodes of the tree where (sum, count) 
    #   information can be found, provided by e.g. aggregateLeaves
    #   :nameKey [String, Symbol] the name of the key where the name of the node can be found
    #   :rootChildrenKey [String, Symbol] the name of the key where the children of the root node
    #     can be found
    #   :intChildrenKey [String, Symbol] the name of the key where the children of internal nodes
    #     can be found
    #   :delim [String] the delimiter of path if it is given as a String
    #   :addKey [String, Symbol] the name of the key that is to be added or set for the @path@
    #   :operationKey[String] the name of the operation, supported operations are -
    #     'sum', 'average', 'max' and 'min'
    # @return [Symbol, Array] Symbol indicating the type of failure or success  or Array of data type;
    #     symbols include
    #     :no_rootKey - when the dataTree has no :rootChildrenKey
    #     :no_operationKey - when the value of :operationKey is not supported.
    def self.getNewDataTypeFromTree(dataTree, type='row', depth=0, opts={})
    
      retVal = Array.new()
      valArray = Array.new()
      supOpts = { :dfsKey => "count", :nameKey => "name", :rootChildrenKey => "Data",
                  :leafKey => "cell", :intChildrenKey => "data", :delim => ".", :addKey => nil,
                  :operationKey => nil
                }
      opts = supOpts.merge(opts)
      childrenKey = opts[:rootChildrenKey]
      if(dataTree.key?(childrenKey))
        dataElem = dataTree[childrenKey]
        dataElem.each {|node| 
          values = dfs(node, depth, {:op => 'value'})
          if(values.first.is_a?(Array)) # not a very good solution, revisit and fix to do
            values.each {|val| valArray << val}
          else
            valArray << values  
          end
        }
      else
        retVal = :no_rootKey
      end
    
      valArray = valArray.transpose if(type == 'col')
      if(opts[:operationKey])
        if(opts[:operationKey] == 'sum')
          valArray.each {|valList| retVal << valList.inject {|sum, val| sum + val } }
        elsif(opts[:operationKey] == 'max')
         valArray.each {|valList| retVal << valList.max }
        elsif(opts[:operationKey] == 'min')
          valArray.each {|valList| retVal << valList.min }
        elsif(opts[:operationKey] == 'average')
          valArray.each {|valList| 
           total = valList.inject {|sum, val| sum + val }
           average = (total/valList.length.to_f)
           retVal << average
          }
        elsif(opts[:operationKey] == 'percentage')
          total = []
          valArray.each {|valList| total << valList.inject {|sum, val| sum + val }}
          valArray.each_with_index{|val, ii|
            tmp = []
            if(total[ii] > 0)
              val.each {|value|
                value = (value/(total[ii]*1.0))*100
                tmp << value
              }
              retVal << tmp
            else
              retVal << val
            end
          }
        else
          retVal = :not_supported  
        end
        
      else
        retVal = :no_operationKey
      end
      return retVal
    end
  
    # Makes a subtree to the leaf node of a data tree.
    # It checks for @intChildrenKey@ and adds a new value to the name of @:addKey@
    # to the leaf node of the tree. Is useful in mimicking a original tree and
    # generating a column node for a original tree. @see getColNode.
    # @param [Hash] hash a hash structure to which the subtree is to be built
    # @param [String] name value for the key name :nameKey that is to be inserted at
    # the same level
    # @param [Hash] opts options hash with the following keys supported
    #   :dfsKey [String, Symbol] the name of the key in nodes of the tree where (sum, count) 
    #   information can be found, provided by e.g. aggregateLeaves
    #   :nameKey [String, Symbol] the name of the key where the name of the node can be found
    #   :rootChildrenKey [String, Symbol] the name of the key where the children of the root node
    #     can be found
    #   :intChildrenKey [String, Symbol] the name of the key where the children of internal nodes
    #     can be found
    #   :delim [String] the delimiter of path if it is given as a String
    #   :addKey [String, Symbol] the name of the key that is to be added or set for the @path@
    #   :opeationKey[String] the name of the operation, supported operations are -
    #     'sum', 'average', 'max' and 'min'
    # @param [Array<Hash>] list of hashes that is to be added to the :addKey value.
    # @return [Hash] hash the new tree that is built from the @name@ and @dataValue@
    def self.buildSubTreeTemplate(hash, name, opts={}, dataValue=[{}])
      supOpts = { :dfsKey => "count", :nameKey => "name", :rootChildrenKey => "Data",
                  :leafKey => "cell", :intChildrenKey => "data", :delim => ".", :addKey => nil,
                  :operationKey => nil
                }
      opts = supOpts.merge(opts)
      unless(hash.key?(opts[:intChildrenKey]))
        hash[opts[:nameKey]] = name
        hash[opts[:addKey]] = dataValue
      else
        buildSubTreeTemplate(hash[opts[:intChildrenKey ]][0], name, opts, dataValue)
      end
      return hash
    end
    
    # Generates a column node (a sub tree) mimicking the structure and depth
    # of the original tree.
    # @param [Hash] dataTreeNode a json-like tree data structure.
    # @param [String] label name of the new column node that is added to the :nameKey
    # @param [Array<Integer>] col values of the columns.
    # @return [Symbol, Hash] Symbol indicating the type of failure  or new column node;
    #     symbols include
    #     :invalid_columnSize - when the size of @col@ fail to match the size of the deepest node 
    def self.getColNode(dataTreeNode, label, col)
      supOpts = { :nameKey => "name", :rootChildrenKey => "Data",:leafKey => "cell",
                :intChildrenKey => "data", :delim => ".", :addKey => nil
              }
      retVal = []
      new = []
      tmp = {}
      copyNode = Marshal.load(Marshal.dump(dataTreeNode))
      while(copyNode.key?(supOpts[:intChildrenKey]))
        new = copyNode[supOpts[:intChildrenKey]]
        copyNode = copyNode[supOpts[:intChildrenKey]][0]
        if(new[0].key?(supOpts[:leafKey]))
          if(new.length != col.length)
            retVal = :invalid_columnSize
            break
          else
            new.each_with_index{|leafnode, ii|
              leafnode[supOpts[:leafKey]]['value'] = col[ii]
            }
          end
          tmp = buildSubTreeTemplate(tmp, label, {:addKey => supOpts[:intChildrenKey]}, new)
          retVal = tmp
        else
          tmp = buildSubTreeTemplate(tmp, "", {:addKey => supOpts[:intChildrenKey]}, [{}])
        end
      
      end
      return retVal
    end
    
    # Generates a  list of leaf nodes which represents the 'row' nodes
    # @param [String] label name of the new row node that is added to the :nameKey
    # @param [Array<Integer>] row values of the rows.
    # @return [<Array[Hash]>] retVal lsit of hashes, where each hash is a row node.
    def self.getRowNode(label, row)
      supOpts = { :nameKey => "name", :rootChildrenKey => "Data", :leafKey => "cell",
                :intChildrenKey => "data", :delim => ".", :addKey => nil
              }
      retVal = []
      row.each{|rowValue|
        retVal << { supOpts[:nameKey] => label, supOpts[:leafKey] => {"value" => rowValue} }
      }
      return retVal
    end
    
    # Gets all the names of each subtree. 
    # CAUTION: Assuming that the transformed data document has the
    # same property 'names' at all the levels.
    def self.getNameKeys(dataTree, opts={}, first=false)
      subOpts = { :nameKey => "name", :rootChildrenKey => "Data", :leafKey => "cell",
                :intChildrenKey => "data", :delim => ".", :getKey => nil
              }
      opts = subOpts.merge(opts)
      unless(opts[:getKey].nil?)
        retVal = opts[:getKey].keys().inject({}){|hh, key| hh[key] = []; hh}
        tmpRet = Array.new()

        #First partition 
        if(dataTree.key?(opts[:rootChildrenKey]))
          level = dataTree[opts[:rootChildrenKey]]
          opts[:getKey].each_key{|key|
            tmpRet = []
            level.each{ |item|
              key == 'metadata' ? (tmpRet << item[key] rescue nil) : tmpRet << item[key]
            }
            retVal[key] << tmpRet 
            
          }
          # CAUTION.
          if(first)
            while(level.first.key?(opts[:intChildrenKey]))
              level = level.first[opts[:intChildrenKey]]
              opts[:getKey].each_key{|key|
                tmpRet = []
                level.each{ |item|
                  key == 'metadata' ? (tmpRet << item[key] rescue nil) : tmpRet << item[key]
                }
                retVal[key] << tmpRet
              }
            end
          else
            while(level.last.key?(opts[:intChildrenKey]))
              level = level.last[opts[:intChildrenKey]]
              opts[:getKey].each_key{|key|
                tmpRet = []
                level.each{ |item|
                  key == 'metadata' ? (tmpRet << item[key] rescue nil) : tmpRet << item[key]
                }
                retVal[key] << tmpRet
              }
            end
         end
         else
           retVal = :no_rootKey
         end
      else
        retVal = :no_getKey
      end
    return retVal
  end




    # Deletes a node from dataTree
    # @param [Hash] dataTree a json-like tree data structure
    # @param [String] path either an opts[:delim] delimited string providing a mongo-style  
    # path to the subtree root in dataTree or an array of such tokens
    # @return [Symbol] Symbol indicating the type of failure or success ; symbols include
    #     :no_path - the path provided by the path variable is invalid
    #     leaf node, :leafKey.     
    #     :deleted - @path@ successfully deleted.
    def self.deleteNodeFromTree(dataTree, path)
      opts = { :dfsKey => "count", :nameKey => "name", :rootChildrenKey => "Data", 
                  :leafKey => "cell", :intChildrenKey => "data", :delim => ".", :addKey => nil
                }
      nodeToDel = {}
      retVal = :deleted
      dataElem = []
      if(path.is_a?(String))
        #path = path.split(opts[:delim])
        path = path.gsub(/\\\./, "\v").split('.').map{ |xx| xx.gsub(/\v/, '.') }
      end
      pi = 0
      dataElem = dataTree
      childrenKey = opts[:rootChildrenKey]
      if(dataElem.nil?)
        retVal = :no_path
      else
        while(pi < path.size)
          pathElem = path[pi]
          #dataElem = dataElem[childrenKey].find { |node| node[opts[:nameKey]] == pathElem }
          #dataElem = (dataElem[childrenKey] and dataElem[childrenKey].find { |node| node[opts[:nameKey]] == pathElem })
          dataElem[childrenKey].find { |node| 
          if(node[opts[:nameKey]] == pathElem and pathElem == path.last) 
            dataElem = dataElem[childrenKey]
            nodeToDel = node
            break
          elsif(node[opts[:nameKey]] == pathElem)
            dataElem = node
          end
          }
          if(dataElem.nil?)
            retVal = :no_path
            break
          end
          pi += 1
          childrenKey = opts[:intChildrenKey]
        end
      end
      if(!dataElem.empty?)
        dataElem.delete(nodeToDel)
      else
        retVal = :invalid_tree
      end
      return retVal
    end


  
  end
end; end; end; end


