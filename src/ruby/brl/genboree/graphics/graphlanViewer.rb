#!/usr/bin/env ruby

require 'Newick'

module BRL;module Genboree; module Graphics
      
  class NewickScaler
    attr_reader :tree
    
    def initialize(treeFileName)
      if(File.exists?(treeFileName))
      @tree = NewickTree.new(File.read(treeFileName))
    else # tree string rather than file
      @tree = NewickTree.new(treeFileName)
    end
    end
    
    
    def minScaleTree(scaleFileName,minScale=10.0)
      minLength = @tree.root.descendants.select{|xx| (xx.edgeLen>0)}.map{|yy|yy.edgeLen}.min
      if((!minLength.nil?) and (minLength < minScale)) then
        @tree.root.descendants.each{|dd|
          dd.edgeLen = dd.edgeLen*minScale/minLength unless (dd.edgeLen <= 0 )
        }
      end
      fh=File.open(scaleFileName,"w")
      # bug in to_s that puts extra "\n;" at end which messes up graphlan
      fh.puts @tree.to_s.gsub(/\s;$/,"")
      fh.close
    end
    
    def logScaleTree(logFileName,minScale=10.0,logbase=nil)
      minLength = @tree.root.descendants.select{|xx| (xx.edgeLen>0)}.map{|yy|yy.edgeLen}.min
      if((!minLength.nil?) and (minLength < minScale)) then
        @tree.root.descendants.each{|dd|
          dd.edgeLen = Math.log(dd.edgeLen*minScale/minLength) unless (dd.edgeLen <= 0 )
          dd.edgeLen /= Math.log(logbase) unless (logbase.nil?)
        }
      end
      fh=File.open(logFileName,"w")
      # bug in to_s that puts extra "\n;" at end which messes up graphlan
      fh.puts @tree.to_s.gsub(/\s;$/,"")
      fh.close
    end
    
    def equiScaleTree(eqFileName,branchLength = 10)
      @tree.root.descendants.each{|dd|
          dd.edgeLen = branchLength
        }
      fh=File.open(eqFileName,"w")
      # bug in to_s that puts extra "\n;" at end which messes up graphlan
      fh.puts @tree.to_s.gsub(/\s;$/,"")
      fh.close
    end
    
    def getMaxTreeDepth()
      leafDepths = @tree.root.leaves.map{|tt|tt.nodesToAncestor(@tree.root)}
      return leafDepths.max
    end
    
    def getLongestNodeNameLength()
      nodeNameLengths = @tree.root.leaves.map{|tt|tt.name.length}
      return nodeNameLengths.max
    end
    
    def getLeafCount()     
      return @tree.taxa.length
    end
    #
    #  def removeTrackColons(newickString,replacementChar='|')
    #  # First change all the colons representing branch length to ! assumes track name does not contain !
    #  tempString = newickString.gsub(/:([\d\.]+[\),])/){|xx| "!"+ $~[1]}
    #  # Now the only colons left are from the track names. So replace them
    #  tempString.gsub!(/:/,replacementChar)
    #  # Finally revert all the !s to colons
    #  tempString.gsub!(/!/,":")
    #  return tempString
    #end
  end
      
      
  class GraphlanViewer

    attr_reader :treeString
    attr_reader :tree
    attr_reader :annoString

    def initialize(treeFileName)
      @treeString = File.read(treeFileName)
      parseTree()
      @fontSize = 10
    end

    def setAnnoString(annoString)
      @annoString = annoString
    end



    def parseTree()
      @tree = NewickTree.new(@treeString)
    end
    
    def generateAnnotationFile(fileName)
      fh = File.open(fileName,"w")
      if(@annoString.nil?) then
    @annoString = <<-END
    total_plotted_degrees	300
    clade_separation	0.02
    *	branch_bracket_depth	0.25
    *	branch_bracket_width	1.0
    annotation_background_alpha	0.15
    annotation_legend_font_size	#{@fontSize}
    annotation_font_size	#{@fontSize}
    annotation_font_stretch	0
    clade_marker_size	0
        END
      end

      fh.print @annoString
      @tree.taxa.each {|leaf|
        fh.puts "#{leaf}\tannotation\t#{leaf}"
        fh.puts "#{leaf}\tannotation_rotation\t90"
      }
      fh.close()
    end

    def drawGraphlanImage(treeFileName, annotationFileName, imageFileName, logFileName="graphlan.log")
      nsTree = NewickScaler.new(treeFileName)
      dpi = 62.0
      # How big (radially in inches) is each additional level in the tree?
      levelSize = 0.5 
      leafCount = nsTree.getLeafCount
      longestName = nsTree.getLongestNodeNameLength
      # No. of leaves in binary tree = 2^n where n is number of levels. So n = log2(leafcount)
      circleD = 2*Math.log(leafCount)*levelSize/Math.log(2)
      
      # dpi to go from pixels to inches
      fontV = ((longestName*@fontSize*0.6)/dpi).ceil
      # for a given image size how much space will the circle diameter occupy in each dimension
      circleRatio = 0.7
      # minimum padding added to every image
      padVal = 1
      # what proportion of total length allocated is the length allocated for node names
      fontCircleRatio = (fontV/(fontV+circleD))
      
      # This is the image size we have calculated
      imageSize = (circleD + fontV).ceil
      # However for ANY image size the circle will occupy 0.7 of the space.
      # So if the remaining space is not enough for node names, you have to pad the image with the difference to avoid node names being cut off.
      if(fontCircleRatio > (1-circleRatio)) then padVal = (fontV*dpi - circleRatio*imageSize)/dpi end
      treeFileName = File.expand_path(treeFileName)
      annotationFileName = File.expand_path(annotationFileName)
      system("module load graphlan")
      system("graphlan_annotate.py --annot #{annotationFileName} #{treeFileName}  #{treeFileName}.xml 1>#{logFileName} 2>&1" )
      # Ceil to be on the safe side
      cmd = "graphlan.py --size #{imageSize.ceil} --pad #{padVal.ceil} #{treeFileName}.xml #{imageFileName}  1>>#{logFileName} 2>&1"
      $stderr.debugPuts(__FILE__,__method__,"Graphlan Call",cmd.inspect)
      system(cmd)
    end

  end

end;end;end
#main
#
#gv = BRL::Genboree::Graphics::GraphlanViewer.new(ARGV[0])
#gv.generateAnnotationFile(ARGV[1])
#gv.drawGraphlanImage(ARGV[0],ARGV[1],ARGV[2])
