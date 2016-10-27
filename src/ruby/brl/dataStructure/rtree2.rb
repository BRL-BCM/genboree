#!/usr/bin/env ruby

# ##############################################################################
# REQUIRED CLASSES/MODULES
# ##############################################################################
module BRL ;  module DataStructure

  # ############################################################################
  # MODULE CONSTANTS
  # ############################################################################
  MIN_X, MAX_X, MIN_Y, MAX_Y = 0,2,1,3

  # ############################################################################
  # MODULE METHODS
  # ############################################################################
  class Rect
  	attr_accessor :minX, :minY, :maxX, :maxY
  	
  	def initialize(minX, minY, maxX, maxY)
  		@minX, @minY, @maxX, @maxY = minX, minY, maxX, maxY
  		@area = nil
  	end
  	
  	def area()
  	  @area = ((@maxX-@minX) * (@maxY-@minY)).abs if(@area.nil?)
  	  return @area
  	end
  	
  	def enlargeUsingRect(rect)
    	@minX = rect.minX if(rect.minX < @minX)
      @minY = rect.minY if(rect.minY < @minY)
      @maxX = rect.maxX if(rect.maxX > @maxX)
      @maxY = rect.maxY if(rect.maxY > @maxY)
      @area = nil
      return
  	end
  	
  	def getEnlargedRect(rect)
  	  enlgRect = self.dup
  	  enlgRect.enlargeUsingRect(rect)
  	  return enlgRect
  	end
  	
  	def areaOfEnlargedRect(rect)
  	  return ( 
  	           ( ((@maxX >= rect.maxX) ? @maxX : rect.maxX) - ((@minX <= rect.minX) ? @minX : rect.minX) ) *
  	           ( ((@maxY >= rect.maxY) ? @maxY : rect.maxY) - ((@minY <= rect.minY) ? @minY : rect.minY) )
  	         ).abs
  	end
  	
  	def to_s()
  	  return "[ #{minX}, #{minY}, #{maxX}, #{maxY} ]"
  	end
  end
  
  class RTreeNode
    attr_accessor :isLeaf, :object, :bbox, :children
    
    # OK, OK2
    # rect = [ min_x, min_y, max_x, max_y ]
    def initialize(object, rect, isLeaf=false)
      @bbox = rect.dup
      if(object.nil?)
        @children = [] # storing nil objects is free :)
      else
        @children = [ object ]
      end
      @isLeaf = isLeaf
    end
    
    # OK, OK2
    def isLeaf?()
      return @isLeaf
    end
    
    # OK, OK2
    def isNonLeaf?()
      return !@isLeaf
    end
    
    # OK, OK2
    def bboxArea()
      return @bbox.area()
    end
    
    def addNonLeafNode(node)
      @children << node
      @bbox.enlargeUsingRect(node.bbox)
    end
    
    # OK, OK2: Recursive string representation
    def to_s(level=0)
      asStr = ''
      currNode = self
      
      if(currNode.isLeaf) # Dump
        level += 1
        asStr += "#{'  '*level} (#{level}) Leaf Node ID: #{currNode.id} bbox: #{currNode.bbox}\n"
        level += 1
        ii = nil
        currNode.children.each_index { |ii|
          asStr += "#{'  '*level} (#{level}) Object @ #{ii}: #{currNode.children[ii].inspect()}\n"
        }
        level -= 2 
      else # is non-leaf
        level += 1
        asStr += "#{'  '*level} (#{level}) Subtree Node ID: #{currNode.id} bbox: #{currNode.bbox} num child nodes: #{currNode.children.length}\n"
        child = nil
        currNode.children.each { |child|
          asStr += child.to_s(level)
        }
        level -= 1
      end
      return asStr
    end
    
  end # END: class RTreeNode
  
  class RTree
    # ############################################################################
    # CONSTANTS
    # ############################################################################
      
    # ############################################################################
    # ATTRIBUTES
    # ############################################################################
    attr_reader :minNodeSize, :maxNodeSize
    attr_reader :root
    # ############################################################################
    # METHODS
    # ############################################################################
    def initialize(minNodeSize=2, maxNodeSize=5)
      @minNodeSize, @maxNodeSize = minNodeSize, maxNodeSize
      @root = nil
      @pickedSeeds = Array.new(2)           # Reusable array for picking seeds
      @pickNextArray = Array.new(3)         # Reusable array for picking next
      @enlargedRect = Rect.new(0,0,0,0)     # Reusable Rect for enlarged rect.
    end
  
    # OK: Query the tree to find which objects contain the point.
    # Point = [xx, yy]
    def queryPoint(point=[], node=@root)
      theObjs = []  # Returned
      return theObjs if(point.nil? or point.empty? or node.nil?)
      
      return theObjs unless(  point[0] >= node.bbox.minX and
                              point[0] < node.bbox.maxX and
                              point[1] >= node.bbox.minY and
                              point[1] < node.bbox.maxY)
      if(node.isLeaf)
        theObjs += node.children
      else
        entry = nil
        node.children.each { |entry|
          theObjs += self.queryPoint(point, entry)
        }
      end
      return theObjs
    end
    
    # OK: Return objects which fall completely within the provided rectangle
    # rect = [ minX, minY, maxX, maxY ]
    def withinRect(rect, node=@root)
      theObjs = [] # returned
      return theObjs if(node.nil?)
      entries = [ node ]
  
      while(entries.length > 0)
        currNode = entries.pop()
        if( currNode.bbox.minX >= rect.maxX or   # right out of bounds
            currNode.bbox.maxX < rect.minX or   # left out of bounds
            currNode.bbox.minY >= rect.maxY or   # above out of bounds
            currNode.bbox.maxY < rect.minY)     # below out of bounds
          next                              # Then entry CANNOT be contained in rect (still may not be totally within, but any of these conditions make it impossible
        else                                
          if( currNode.isLeaf and
              currNode.bbox.minX >= rect.minX and 
              currNode.bbox.maxX < rect.maxX and
              currNode.bbox.minY >= rect.minY and
              currNode.bbox.maxY < rect.maxY)
            theObjs += currNode.children    # Then is leaf and is contained fully within rect
          elsif(!currNode.isLeaf)           # Examine kids of non-leaf
            entry = nil
            currNode.children.each { |entry|
              entries << entry
            }
          end
        end
      end 
      return theObjs
    end
    
    # OK: non-recursive from liuyi at cis.uab.edu
    # rect = [ minX, minY, maxX, maxY ]
    def overlapsRect(rect, node=@root)
      theObjs = [] # returned
      return theObjs if(node.nil?)
      entries = [ node ]
  
      while(!entries.empty?)    
        currNode = entries.pop()
        if( currNode.bbox.minX > rect.maxX or    # right out of bounds   
            currNode.bbox.maxX < rect.minX or    # left out of bounds    
            currNode.bbox.minY > rect.maxY or    # above out of bounds   
            currNode.bbox.maxY < rect.minY)      # below out of bounds   
          next                              # Then entry CANNOT be partially overlapping rect
        else                                # Else overlaps or is contained within
          if(currNode.isLeaf)
            theObjs += node.children
          else
            entry = nil
            node.children.each { |entry|
              entries << entry
            }
          end
        end        
      end
      return theObjs
    end
    
    # OK: Get all the objects in the tree, or under the provided node
    # ARJ: made it non-recursive
    def objects(node=@root)
      theObjs = [] # Returned
      return theObjs if(node.nil?)
      entries = [ node ]
      
      while(!entries.empty?)
        currNode = entries.pop()
        if(currNode.isLeaf)
          theObjs += node.children
        else
          node.children.each { |child|
            entries << child
          }
        end
      end
      return theObjs
    end
    
    # OK: Insert an object having the provided bounding box [minX, minY, maxX, maxY]
    # SLOW, DUE TO METHODS IT CALLS
    def insert(object, rect)
      if(rect.kind_of?(Array))
        rect = Rect.new(rect[MIN_X], rect[MIN_Y], rect[MAX_X], rect[MAX_Y])
      end
      child = RTreeNode.new(object, rect, true)
      if(@root.nil?)
        @root = RTreeNode.new(child, rect, false)
      else
        node = self.chooseSubTree(rect)
        $stderr.puts "\n\nWARNING: node chosen to add to is a leaf:\n\n#{node.to_s(3)}\n\n" if(node.isLeaf)
        node.children << child
        self.quadraticSplit(node.children) if(node.children.length > @maxNodeSize)
      end
      return
    end

    # OK: Remove the object from the tree
    def remove(object)
      parent, indexOfLeaf, leaf, indexOfObj = *self.getLeaf(object)
      return if(leaf.nil?)
  
      # remove the object
      leaf.children.delete_at(indexOfObj)
  
      # is the leaf too small now?
      if(!parent.nil? and (leaf.children.length < @minNodeSize))
        # remove the leaf
        parent.children.delete_at(indexOfLeaf)
  
        # is the parent now too small?
        if(parent.children.length < @minNodeSize)
          # yes, move the children up
          newChildList = []
          entry = child = nil
          parent.children.each { |entry|
            entry.children.each { |child|
              newChildList << child
            }
          }
          parent.children = newChildList
        end
  
        self.setBBoxes()
  
        # reinsert the orphans
        child = nil
        leaf.children.each { |child|
          node = self.chooseSubTree(child.bbox)
          node.children += child
          self.quadraticSplit(node.children) if(node.children.length > @maxNodeSize)
        }
      else
        self.setBBoxes()
      end
    end
    
    # OK: Returns the leaf which contains the object. The leaf will be:
    # [ leaf parent, index of leaf, leaf node, index of object in leaf ]
    def getLeaf(object, node=@root, indexOfLeaf=0, parent=nil)
      return nil if(node.nil? or !node.respond_to?("isLeaf?"))
      ii = nil
      node.children.each_index { |ii|
        entry = node.children[ii]
        if(entry.isLeaf)
          return [parent, indexOfLeaf, node, ii] if(entry.children[0] == object)
        else
          retVal = self.getLeaf(object, entry, ii, node)
          return retVal unless(retVal.nil?)
        end
      }
      return nil
    end
    
    # OK: String representation of tree (non-recursive from RTreeNode.to_s()
    def to_s(node=@root)
      level = 0
      return 'root => nil' if(node.nil?)
      asStr = node.to_s(level)
      return asStr
    end
    
    # OK: Set the bbox for this node and all children.
    # Recursive visitor.
    def setBBoxes(node=@root)
      return nil if(node.nil?)
       
      if(node.isLeaf)
        return node.bbox
      else
        theBBox = nil
        child = nil
        node.children.each { |child|
          childBBox = self.setBBoxes(child)
          if(theBBox.nil?)
            theBBox = childBox
          else
            theBBox.enlargeUsingRect(childBox)
          end
        }
        node.bbox = theBBox.dup
        return theBBox
      end
    end

    # OK: Find the correct subtree given a bbox (say, to add a node to or something)
    # rect = [ minX, minY, maxX, maxY ]
    # SLOW, DUE TO METHODS IT CALLS
    def chooseSubTree(rect)
      returnNode = nil
      if(@root.nil?)
        child = RTreeNode.new(nil, rect, true)
        @root = RTreeNode.new(child, rect, false)
        returnNode = @root
      else
        returnNode = @root
        parentNode = nil
        loop {
          returnNode.bbox.enlargeUsingRect(rect)
          if( returnNode.children.empty? or
              returnNode.children[0].isLeaf)
            break
          else
            chosen = nil
            neededEnlargementOfChosen = nil
            areaOfChosen = nil
            child = nil
            returnNode.children.each { |child|
              childRect = child.bbox
              childArea = child.bboxArea()
              neededEnlargement = childRect.areaOfEnlargedRect(rect) - childArea
              if( chosen.nil? or
                  neededEnlargement < neededEnlargementOfChosen or
                  childArea < areaOfChosen)
                # Then need to choose this one [instead of current chosen one, if any]
                chosen = child
                neededEnlargementOfChosen = neededEnlargement
                areaOfChosen = childArea
              end
            }
            if(!chosen.isLeaf)
              parentNode = returnNode
              returnNode = chosen
              next
            else # Then it is a leaf, but it is where we should be. Take non-leaf above this child that is a leaf and Stop.
              returnNode = parentNode
              break
            end
          end
        }
      end
      return returnNode
    end

    # OK:
    # SLOW, DUE TO IT AND STUFF IT CALLS
    def quadraticSplit(nodeList)
      @pickedSeeds[0] = @pickedSeeds[1] = @pickedSeeds[2] = nil
      self.pickSeeds(nodeList) # Not implemented right
      orphan1 = nodeList.delete_at(@pickedSeeds[1])
      orphan2 = nodeList.delete_at(@pickedSeeds[0])
      newNode1 = RTreeNode.new(orphan1, orphan1.bbox, false)
      newNode2 = RTreeNode.new(orphan2, orphan2.bbox, false)
      
      begin
        distributeEntry(nodeList, newNode1, newNode2)
      end until(  nodeList.empty? or
                  newNode1.children.length == (@maxNodeSize - @minNodeSize + 1) or
                  newNode2.children.length == (@maxNodeSize - @minNodeSize + 1) )
                  
      unless(nodeList.empty?)
        if(newNode1.children.length < newNode2.children.length)
          while(nodeList.length > 1)
            newNode1.addNonLeafNode(nodeList.pop)
          end
        else
          while(nodeList.length > 1)
            newNode2.addNonLeafNode(nodeList.pop)
          end
        end
      end
      nodeList.push(newNode1)
      nodeList.push(newNode2)
      return
    end
  
    # OK: Maybe Buggy for dd tho? -- The while loops don't seem to do anything due to dd issue?
    # SLOW, DUE TO IT AND METHODS IT CALLS\
    # BUG:
    # - This is not implemented right and probably causing slowdown.
    # - Currently, it will *always* pick e2 = nodeList.length-1 and e1 = nodeList.length-2
    # - Leave seeds in @pickedSeeds
    def pickSeeds(nodeList)
      # All it does right now is this:
      @pickedSeeds[0] = ((nodeList.length - 2) < 0  ? 0 : (nodeList.length - 2))
      @pickedSeeds[1] = nodeList.length-1
      return
      
      # BUGGY, Fix
      enlgRect = Rect.new(0,0,0,0)
      dd = nil
      e1 = 0
      while(e1 < nodeList.length-1)
        rect1 = nodeList[e1].bbox
        area1 = rect1.area()
        e2 = e1+1
        while(e2 < nodeList.length)
          rect2 = nodeList[e2].bbox
          dTest = rect1.areaOfEnlargedRect(rect2) - area1 - rect2.area()
          if(dd.nil? or dTest > dd) # BUG???? but dd is never set anywhere!!!
            @pickedSeeds[0] = (e1 > e2 ? e2 : e1) # min
            @pickedSeeds[1] = (e1 > e2 ? e1 : e2) # max
          end
          e2 += 1
        end
        e1 += 1
      end
      return 
    end
    
    # OK:
    # SLOW, DUE TO IT AND METHODS IT CALLS
    def distributeEntry(fromList, toNode1, toNode2)
      areaOfTo1 = toNode1.bbox.area()
      areaOfTo2 = toNode2.bbox.area()
      @pickNextArray[0] = @pickNextArray[1] = @pickNextArray[2] = nil
      self.pickNext(fromList, toNode1, toNode2, areaOfTo1, areaOfTo2)
      cmpResult = ((@pickNextArray[1] - areaOfTo1) <=> (@pickNextArray[2] - areaOfTo2))
      if(cmpResult == 0)
        cmpResult = (areaOfTo1 <=> areaOfTo2)
        if(cmpResult == 0)
          cmpResult = (toNode1.children.length <=> toNode2.children.length)
        end
      end
  
      if(cmpResult <= 0)
        toNode1.addNonLeafNode(fromList[@pickNextArray[0]])
      else
        toNode2.addNonLeafNode(fromList[@pickNextArray[0]])
      end
      fromList.delete_at(@pickNextArray[0])
      return
    end
  
    # OK:
    # SLOW
    # sets nextArray to be :[ theNext, areaOfEnlarged1, areaOfEnlarged2 ]
    def pickNext(from, to1, to2, areaOfTo1, areaOfTo2)
      @pickNextArray[0] = maxDiff = @pickNextArray[1] = @pickNextArray[2] = nil
      coverOfTo1 = to1.bbox
      coverOfTo2 = to2.bbox
      ii = nil
      from.each_index { |ii|
        a1 = coverOfTo1.areaOfEnlargedRect(from[ii].bbox)
        @pickNextArray[1] = a1 if(@pickNextArray[1].nil?)
        a2 = coverOfTo2.areaOfEnlargedRect(from[ii].bbox)
        @pickNextArray[2] = a2 if(@pickNextArray[2].nil?)
        diff = ( (@pickNextArray[1] - areaOfTo1) - (@pickNextArray[2] - areaOfTo2)).abs
        if(@pickNextArray[0].nil? or diff > maxDiff)
          @pickNextArray[0] = ii
          maxDiff = diff
          @pickNextArray[1] = a1
          @pickNextArray[2] = a2
        end
      }
      return
    end
  end

end ; end
#=begin
#
#=head1 NAME
#
#Tree::R - Perl extension for the Rtree data structure and algorithms
#
#=head1 SYNOPSIS
#
#  require 'brl/dataStructure/rtree'
#  rTree = BRL::DataStructure::RTree.new()
#
#  # POPULATE:
#  # You need to provide the "bounding-box" array [minx, maxx, miny, maxy]
#  # when inserting. One easy way is if the objects you insert have a
#  # "bbox()" method, but this is up to you:
#  objects.each { |object|
#    bbox = object.bbox() # [ minx, maxx, miny, maxy ]
#    rTree.insert(object, bbox)  # or <<
#  }
#  
#  # QUERY POINT: 
#  aPoint = (123, 456)                 # (x,y)
#  results = rTree.queryPoint(aPoint)  # all objects containing point
#  results.each { |object|
#      # point is in object's bounding box
#  }
#
#  # QUERY RECT (WITHIN):
#  rect = [ 123, 456, 789, 1234 ]      # [minx,maxx,miny,maxy]
#  results = rTree.withinRect(rect)    # all objects completely within rect
#  results.each { |object|
#      # object is within rect
#  }
#
#  # QUERY RECT (OVERLAP):
#  results = rTree.overlapsRect(rect)
#  results.each { |object|
#      # object's bounding box and rectangle overlap
#  }
#
#=head1 DESCRIPTION
#
#R-trees store and index and efficiently
#looking up non-zero-size spatial objects.
#
#=head1 SEE ALSO
#
#A. Guttman: R-trees: a dynamic index structure for spatial
#indexing. ACM SIGMOD'84, Proc. of Annual Meeting (1984), 47--57.
#
#N. Beckmann, H.-P. Kriegel, R. Schneider & B. Seeger: The R*-tree: an
#efficient and robust access method for points and rectangles. Proc. of
#the 1990 ACM SIGMOD Internat. Conf. on Management of Data (1990),
#322--331.
#
#=head1 AUTHOR
#
#Andrew R Jackson <lt>andrewj@bcm.tmc.edu<gt>
#
#(Rewrite and heavy modification of the Perl version by:
#Ari Jolma, E<lt>ari.jolma at tkk.fiE<gt>)
#
#=head1 COPYRIGHT AND LICENSE
#
#Copyright (C) 2005 by Andrew R Jackson
#Copyright (C) 2005 by Ari Jolma
#
#This library is free software; you can redistribute it and/or modify
#it under the same terms as Ruby itself.
#
#=end
