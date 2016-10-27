#!/usr/bin/env ruby

##############################################################################
# LIBRARIES
# - The first 3 are standard for all apps.
###############################################################################

require 'RMagick'
require 'json'

module BRL ; module Genboree ; module Graphics

  # Basic bar with score, color, type and name

  class Bar
    # The score i.e. height of the bar
    attr_accessor :score
    # The color of the bar. Should be in #00ff00 format
    attr_accessor :color
    # The type of bar. Optional mainly used to infer color if possible
    attr_accessor :type
    # The name of the bar. Used to produce numbering below the bar. Expected to be numeric
    attr_accessor :name
    # The standard deviation of the score associated with the bar.
    attr_accessor :stdev
    def initialize(score = 1.0, color=nil, type=nil, name=nil, sdev=0)
      @score = score
      @color = color
      @type  = type
      @name = name
      @stdev = sdev
    end

  end


  # Container class for settings used in bar glyph drawing.Provides defaulting behavior and
  # eliminates the need to pass long parameter lists to BarGlyphDrawer
  class BarGlyphConfig
    # Height of image
    attr_accessor :imageHeight
    # The maximum score in the image
    attr_accessor :maxScore
    # Every bar's width
    attr_accessor :barWidth
    # Distance between any 2 successive bars bar[x].end to bar[x+1].start
    attr_accessor :barBorder
    # axisWidth - Width of x and y axes
    attr_accessor :axisWidth
    # borderWidth - Uniform padding for image as a whole
    attr_accessor :borderWidth
    # Fontsize for all text on image
    attr_accessor :fontSize
    # The label for the y axis.
    attr_accessor :ylabel
    # The label for the x axis.
    attr_accessor :xlabel
    # The title for the image
    attr_accessor :title
    # The minimum value a maxscore must have to be scaled at 100%
    attr_accessor :minValue
    # To account for different drawing styles based on context
    attr_accessor :imageType
    # Gap between X symbol and x axis for methylation graph special cases
    attr_accessor :baseHeight
    # Represent negative values as absent (x symbol rather than no bar). Typically zero score values should have -1 bar score values.
    attr_accessor :xForNeg

    def initialize
      @imageHeight=102
      @maxScore=1.5
      @barWidth=5
      @barBorder=1
      @axisWidth=1
      @borderWidth=5
      @fontSize=10
      @minValue = 10
      @baseHeight = 2
      @xForNeg = true
    end
  end


  # Takes in an array of bars and draws them into an image

  class BarGlyphDrawer
    attr_accessor :barList

    def initialize(barList)
      @barList = barList
    end

    # Method to avoid repeated initialization code
    def self.newDraw(fontSize)
      draw = Magick::Draw.new
      draw.fill_opacity(1)
      draw.fill('#000000')
      draw.font_family = 'arial'
      draw.pointsize = fontSize
      draw.gravity(Magick::NorthWestGravity)
      return draw
    end

    # Method to avoid repeated initialization code
    def self.newImage(width, height)
      image = Magick::Image.new(width, height)
      image.alpha(Magick::TransparentAlphaChannel)
      return image
    end
    
    def self.drawMessage(message)
        bgc=BarGlyphConfig.new
        drawObj = BarGlyphDrawer::newDraw(bgc.fontSize)
        drawObj.align=Magick::LeftAlign
        drawObj.gravity(Magick::NorthWestGravity)
        drawWidth = bgc.imageHeight
        drawHeight = bgc.imageHeight
        drawObj.text(5, 15, message)
        imgObj = BarGlyphDrawer::newImage(drawWidth,drawHeight)
        drawObj.draw(imgObj)
        imgObj.format = 'png'
        #imgObj.display        
      return imgObj.to_blob
    end

    def draw(bgc) # bgc is a barglyphConfig object
      compImages = Array.new
      barMult = 1
      # If maxScore < 1 use 1 as max else use maxScore
      if(bgc.maxScore == 0)
        barMult = 0
        bgc.maxScore = 1
      elsif(bgc.maxScore < bgc.minValue)
        bgc.maxScore = bgc.minValue
      end

      # Label to be displayed next to y axis
      maxScoreLabel = BarGlyphDrawer::newDraw(bgc.fontSize)
      maxScore = bgc.maxScore.to_i.to_s

      if(bgc.maxScore < 1) then
        nd = 3
        maxScore = ((bgc.maxScore.to_f* 10**nd).round.to_f)/(10**nd)
        maxScore = maxScore.to_s
      end
      mm=maxScoreLabel.get_type_metrics(maxScore)
      # Constant so axes line up across images. Allows for a max of 5 digits
      xOffset = 36
      # Right justify the label
      maxScoreLabel.text(xOffset - (mm.width+mm.max_advance/2), 1, maxScore)
      maxScoreImage = BarGlyphDrawer::newImage(xOffset, mm.height)
      maxScoreLabel.draw(maxScoreImage)
      # Space from bottom of image to x axis
      yOffset = 2*bgc.fontSize

      titleHeight = 0
      titleWidth = 0

      # Title image
      if(!bgc.title.nil?) then
        title = BarGlyphDrawer::newDraw(bgc.fontSize)
        tt=title.get_type_metrics(bgc.title)
        titleHeight = tt.height+1
        titleWidth = tt.width + tt.max_advance/2
        title.align=Magick::CenterAlign
        title.text(titleWidth/2,titleHeight/2+1, bgc.title)
        titleImage = BarGlyphDrawer::newImage( titleWidth, titleHeight)
        title.draw(titleImage)
      end

      # Maximum room available to right of y axis
      maxWidth = [barList.length*(bgc.barWidth + 2*bgc.barBorder), titleWidth].max
      # Numbering below Y axis in two rows. First row numbers of exons. Second row label
      exonLabel = BarGlyphDrawer::newDraw(bgc.fontSize)
      exonLabelWidth = maxWidth
      if(!bgc.xlabel.nil?)
        xx=exonLabel.get_type_metrics(bgc.xlabel)
        maxWidth = [xx.width+xx.max_advance/2, maxWidth].max
        exonLabelWidth = maxWidth
        exonLabel.text(exonLabelWidth/2-(xx.width+xx.max_advance/2)/2, bgc.fontSize, bgc.xlabel)
      end

      # Height of biggest bar in graph. Maximum possible bar height
      maxHeight = (bgc.imageHeight - (2*bgc.borderWidth) - yOffset - bgc.axisWidth - titleHeight)
      xDisp = 0
      @barList.each { |bar|
        image = Magick::Image.new(bgc.barWidth, maxHeight)
        image.alpha(Magick::TransparentAlphaChannel)
        sketch = Magick::Draw.new
        sketch.fill_opacity(1)
        sketch.fill(bar.color)
        if(bar.score < 0 and bgc.xForNeg) then
          # Just draw X to indicate low methylation coeff. because of no coverage
          sketch.line(0, maxHeight-bgc.barWidth-bgc.baseHeight, bgc.barWidth-1, maxHeight-bgc.baseHeight)
          sketch.line(0, maxHeight-bgc.baseHeight, bgc.barWidth-1,maxHeight-bgc.barWidth-bgc.baseHeight)
        else
        # Scale the bar score
        scaledScore = (maxHeight * (1 - bar.score * barMult / bgc.maxScore)).to_i
        sketch.rectangle(0, scaledScore, bgc.barWidth, maxHeight)
        end
        if(bar.stdev!=0) then
          scaledStdev = (maxHeight * (1 - bar.stdev * barMult / bgc.maxScore)).to_i
          sketch.line(bgc.barWidth/2,scaledScore,bgc.barWidth/2,scaledScore+scaledStdev-maxHeight+1)
          sketch.line(0,scaledScore+scaledStdev-maxHeight+1, bgc.barWidth,scaledScore+scaledStdev-maxHeight+1)
        end
        sketch.draw(image)
        compImages << image
        # Only use bars with names for numbering
        if(!(bar.name.nil? or bar.name.empty?))
          exonLabel.text(xDisp+bgc.barBorder, 1, bar.name)
        end
        xDisp += (bgc.barWidth + 2*bgc.barBorder)
      }
      exonLabelImage = BarGlyphDrawer::newImage( exonLabelWidth, yOffset)
      exonLabel.draw(exonLabelImage)
      # Tick marks on yaxis at 0,0.5*max and max
      tickMarkWidth = 5
      tickMarkImage = BarGlyphDrawer::newImage( tickMarkWidth, maxHeight+bgc.axisWidth)
      tickMark = BarGlyphDrawer::newDraw(bgc.fontSize)
      tickMark.line(0, 0, tickMarkImage.columns, 0)
      tickMark.line(0, (maxHeight/2).to_i, tickMarkImage.columns, (maxHeight/2).to_i)
      tickMark.line(0, maxHeight, tickMarkImage.columns, maxHeight)
      tickMark.draw(tickMarkImage)

      # Y axis label
      # Label to be displayed next to y axis
      if(!bgc.ylabel.nil?)
        yaxisLabel = BarGlyphDrawer::newDraw(bgc.fontSize)
        yaxisLabel.align=Magick::CenterAlign
        yaxisLabelWidth = maxHeight - maxScoreImage.rows
        yaxisLabel.text(yaxisLabelWidth/2, xOffset/2, bgc.ylabel)
        yaxisLabelImage = BarGlyphDrawer::newImage(yaxisLabelWidth,xOffset)
        yaxisLabel.draw(yaxisLabelImage)
        # yaxis text is on its side
        yaxisLabelImage.rotate!(270)
      end
      # Width of image as a whole
      compImageWidth = 2*bgc.borderWidth + xOffset + tickMarkWidth+bgc.axisWidth + maxWidth
      # X axis
      xaxisImage = BarGlyphDrawer::newImage(bgc.axisWidth + maxWidth, bgc.axisWidth)
      xaxis = BarGlyphDrawer::newDraw(bgc.fontSize)
      xaxis.rectangle(0, 0, xaxisImage.columns, xaxisImage.rows)
      xaxis.draw(xaxisImage)
      # Y axis
      yaxisImage = BarGlyphDrawer::newImage(bgc.axisWidth, maxHeight)
      yaxis = BarGlyphDrawer::newDraw(bgc.fontSize)
      yaxis.rectangle(0, 0, yaxisImage.columns, yaxisImage.rows)
      yaxis.draw(yaxisImage)
      xDisp  = xOffset+bgc.borderWidth+tickMarkWidth
      # Assemble final image
      compImage = BarGlyphDrawer::newImage(compImageWidth, bgc.imageHeight)
      compImage.composite!(maxScoreImage, bgc.borderWidth, bgc.borderWidth+titleHeight, Magick::OverCompositeOp)
      compImage.composite!(tickMarkImage, (xOffset+bgc.borderWidth), bgc.borderWidth+titleHeight, Magick::OverCompositeOp)
      compImage.composite!(xaxisImage, xDisp, maxHeight + bgc.borderWidth+titleHeight, Magick::OverCompositeOp)
      compImage.composite!(yaxisImage, xDisp, bgc.borderWidth+titleHeight, Magick::OverCompositeOp)
      compImage.composite!(exonLabelImage, xDisp+bgc.axisWidth, maxHeight+bgc.borderWidth+bgc.axisWidth+titleHeight, Magick::OverCompositeOp)
      compImage.composite!(maxScoreImage, bgc.borderWidth, bgc.borderWidth+titleHeight, Magick::OverCompositeOp)
      if(!bgc.ylabel.nil?) then
        compImage.composite!(yaxisLabelImage, bgc.borderWidth, bgc.borderWidth+maxScoreImage.rows, Magick::OverCompositeOp)
      end
      if(!bgc.title.nil?) then
        compImage.composite!(titleImage, xDisp+(maxWidth/2-titleWidth/2), bgc.borderWidth, Magick::OverCompositeOp)
      end

      # Assemble each bar image
      xDisp = xDisp+ bgc.axisWidth
      compImages.each_with_index { |image,ii|
        compImage.composite!(image, (xDisp+bgc.barBorder), bgc.borderWidth+titleHeight, Magick::OverCompositeOp)
        xDisp += (image.columns + (2 * bgc.barBorder))
      }

      # return raw png binary data (in ruby String)
      compImage.format = 'png'
      return compImage.to_blob
    end

  end
end ; end ; end # module BRL ; module Genboree ; module Graphics
