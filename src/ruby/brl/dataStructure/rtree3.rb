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
  	attr_accessor :minX, :minY, :maxX, :maxY, :area
  	
  	def initialize(minX, minY, maxX, maxY)
  		@minX, @minY, @maxX, @maxY = minX, minY, maxX, maxY
  		@area = ((@maxX-@minX) * (@maxY-@minY))
  	end
  	
  	def enlargeUsingRect(rect)
    	@minX = rect.minX if(rect.minX < @minX)
      @minY = rect.minY if(rect.minY < @minY)
      @maxX = rect.maxX if(rect.maxX > @maxX)
      @maxY = rect.maxY if(rect.maxY > @maxY)
      @area = ((@maxX-@minX) * (@maxY-@minY))
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
  	         )
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
      @isLeaf = isLeaf
      if(isLeaf)
        @children = nil
        @object = object
      else # is internal node and 'object' is some node
        @children = [ object ]
      end
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
      return @bbox.area
    end
    
    def addNonLeafNode(node)
      @children << node
      @bbox.enlargeUsingRect(node.bbox)
    end
    
    def clear()
      @children.clear() unless(@isLeaf)
      @object = nil
      @bbox = nil
    end
    
    # OK, OK2: Recursive string representation
    def to_s(level=0)
      asStr = ''
      currNode = self
      
      if(currNode.isLeaf) # Dump
        level += 1
        asStr += "#{'  '*level} (#{level}) Leaf Node ID: #{currNode.id} bbox: #{currNode.bbox}\n"
        level += 1
        asStr += "#{'  '*level} OBJECT -> #{currNode.object.inspect()}\n"
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
      @goodNumChildren = @maxNodeSize - @minNodeSize + 1  # Calculate once, globally.
      @root = nil
      @pickedSeeds = Array.new(2)           # Reusable array for picking seeds (speed)
      @pickNextArray = Array.new(3)         # Reusable array for picking next (speed)
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
        theObjs << node.object
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
            theObjs << currNode.object    # Then is leaf and is contained fully within rect
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
            theObjs << node.object
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
          theObjs << currNode.object
        else
          child = nil
          currNode.children.each { |child|
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
        node = chooseSubTree(rect)
        node.children << child
        quadraticSplit(node.children) if(node.children.length > @maxNodeSize)
      end
      return
    end

    # OK: Remove the object from the tree
    def remove(object)
      grandParentOfLeaf, indexOfParentInGrandParent, parentOfLeaf, indexOfLeafInParent, leafNode = *self.getLeaf(object)
      return if(leafNode.nil?)
  
      # remove the object
      leafNode.clear()
      # remove the leaf from the parent
      parentOfLeaf.children.delete_at(indexOfLeafInParent)
  
      # is the parent of the leaf too small now? (and there is a grandParent to shift stuff into)
      if((parentOfLeaf.children.length < @minNodeSize) and !grandParentOfLeaf.nil?)
        # remove parent from grandparent
        grandParentOfLeaf.children.delete_at(indexOfParentInGrandParent)
        # move the children up into the grandparent
        child = nil
        parentOfLeaf.children.each { |child|
          grandParentOfLeaf.children << child
        }
      
        # adjust the BBoxes for the grandparent and below
        if(grandParentOfLeaf.nil?)
          setBBoxes(parentOfLeaf)
        else
          setBBoxes(grandParentOfLeaf)
          # split the grandParent children if needed
          quadraticSplit(grandParentOfLeaf.children) if(grandParentOfLeaf.children.length > @maxNodeSize)
        end
      else
        setBBoxes(parentOfLeaf)
      end
      return
    end
    
    # OK: String representation of tree (non-recursive from RTreeNode.to_s()
    def to_s(node=@root)
      level = 0
      return 'root => nil' if(node.nil?)
      asStr = node.to_s(level)
      return asStr
    end
    
    # OK: Returns the leaf which contains the object. The returned info will be:
    # [ grandParentOfLeaf,  indexOfParentInGrandParent, parentOfLeaf, indexOfLeafInParent, leafNode ]
    def getLeaf(object, node=@root, indexOfNodeInParent=0, parent=nil)
      return nil if(node.nil? or !node.respond_to?("isLeaf?"))
      ii = nil
      node.children.each_index { |ii|
        child = node.children[ii]
        if(child.isLeaf)
          return [parent, indexOfNodeInParent, node, ii, child] if(child.object == object)
        else
          retVal = self.getLeaf(object, child, ii, node)
          return retVal unless(retVal.nil?)
        end
      }
      return nil
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
          childBBox = self.setBBoxes(child).dup
          if(theBBox.nil?)
            theBBox = childBBox
          else
            theBBox.enlargeUsingRect(childBBox)
          end
        }
        node.bbox = theBBox.dup
        return theBBox
      end
    end

    # OK: Find the correct subtree given a bbox (to add a node to)
    def chooseSubTree(rect)
      returnNode = parentNode = @root
      loop {
        returnNode.bbox.enlargeUsingRect(rect)
        chosen = neededEnlargementOfChosen = areaOfChosen = child = nil
        
        returnNode.children.each { |child|
          childRect = child.bbox
          childArea = childRect.area
          neededEnlargement = childRect.areaOfEnlargedRect(rect) - childArea
          if( chosen.nil? or
              neededEnlargement < neededEnlargementOfChosen or  # Want smallest possible enlargement
              childArea < areaOfChosen)                         # Or Want to expand smallest boxes first
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
      }
      return returnNode
    end

    # OK:
    # SLOW, DUE TO IT AND STUFF IT CALLS
    def quadraticSplit(nodeList)
      self.pickSeeds(nodeList)
      
      orphan1 = nodeList.delete_at(@pickedSeeds[1])
      orphan2 = nodeList.delete_at(@pickedSeeds[0])

      if(orphan1.isLeaf)
        orphan1 = RTreeNode.new(orphan1, orphan1.bbox, false)
      end
      if(orphan2.isLeaf)
        orphan2 = RTreeNode.new(orphan2, orphan2.bbox, false)
      end
    
      distributeEntry(nodeList, orphan1, orphan2)
      while(  !(  nodeList.empty? or
                  orphan1.children.length == @goodNumChildren or
                  orphan2.children.length == @goodNumChildren) )
        distributeEntry(nodeList, orphan1, orphan2)
      end
                  
      unless(nodeList.empty?)
        if(orphan1.children.length < orphan2.children.length)
          while(nodeList.length > 1)
            orphan1.addNonLeafNode(nodeList.pop)
          end
        else
          while(nodeList.length > 1)
            orphan2.addNonLeafNode(nodeList.pop)
          end
        end
      end
      nodeList.push(orphan1)
      nodeList.push(orphan2)
      return
    end
  
    # OK:
    # - Leave seeds in @pickedSeeds for speed
    def pickSeeds(nodeList)
      # init @pickedSeeds and base case for speed
      @pickedSeeds[0] = 0
      @pickedSeeds[1] = 1
      chosenAreaDiff = -1
      # go through rest of list (if any)
      if(nodeList.length > 2) # don't bother with all this and min/max assurance if there are no more in the nodeList
        e1 = 0
        lastIndex = nodeList.length-1
        while(e1 < lastIndex)
          rect1 = nodeList[e1].bbox
          e2 = e1 + 1
          while(e2 < nodeList.length)
            rect2 = nodeList[e2].bbox
            currAreaDiff = rect1.areaOfEnlargedRect(rect2) - rect1.area - rect2.area # Maximize this difference for seeds
            if(currAreaDiff > chosenAreaDiff)
              @pickedSeeds[0] = e1
              @pickedSeeds[1] = e2
              chosenAreaDiff = currAreaDiff
            end
            e2 += 1
          end
          e1 += 1
        end
        if(@pickedSeeds[0] > @pickedSeeds[1]) # Want [min_seed, max_seed]:
          @pickedSeeds[0], @pickedSeeds[1] = @pickedSeeds[1], @pickedSeeds[0]
        end
      end
      return 
    end 
    
    # OK:
    # SLOW, DUE TO IT AND METHODS IT CALLS
    def distributeEntry(fromList, toNode1, toNode2)
      areaOfTo1 = toNode1.bbox.area
      areaOfTo2 = toNode2.bbox.area
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
    # returns :[ theNext, areaOfEnlarged1, areaOfEnlarged2 ]
    def pickNext(from, to1, to2, areaOfTo1, areaOfTo2)
      # init the two areas
      @pickNextArray[1] = to1.bbox.areaOfEnlargedRect(from[0].bbox)
      @pickNextArray[2] = to2.bbox.areaOfEnlargedRect(from[0].bbox)
      @pickNextArray[0] = 0
      
      diff = maxDiff = ii = nil
      from.each_index { |ii|
        diff = ( (@pickNextArray[1] - areaOfTo1) - (@pickNextArray[2] - areaOfTo2)).abs
        if(maxDiff.nil?)
          maxDiff = diff
        elsif(diff > maxDiff)
          maxDiff = diff
          @pickNextArray[1] = to1.bbox.areaOfEnlargedRect(from[ii].bbox)
          @pickNextArray[2] = to2.bbox.areaOfEnlargedRect(from[ii].bbox)
          @pickNextArray[0] = ii
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
