#!/usr/bin/env ruby

require 'RMagick'
require 'json'
require 'fileutils'
require 'brl/genboree/graphics/barGlyph'

module BRL ; module Genboree ; module Graphics
  class GeneDrawer
    @colors = {
      "Promoter"=>"#00d500",
      "5UTR"=>"#ffaa00",
      "Exon"=>"#d50000",
      "Intron"=>"#0000c0",
      "3UTR"=>"#ffaa00"
    }

    def self.draw(lffLines, imgName, colorAttribute = nil, typeAttribute = nil, nameAttribute = nil)
      times = Hash.new { |hh, kk| hh[kk] = 0.0 }
      t1 = Time.now.to_f
      barArray = Array.new
      elementStrand = nil
      # Create bars from lff lines 1 per gene element
      lffLines.each_line { |line|
        splitLine = line.chomp.split(/\t/)
        elementName = splitLine[1]
        elementStrand = splitLine[7]
        elementScore = splitLine[9].to_f.abs
        attrs = Hash.new
        avps = splitLine[12].gsub(/\s/,"").split(/;/)
        avps.each { |avp|
          (a,v) = avp.split(/=/)
          attrs[a] = v
        }
        elementColor = attrs[colorAttribute]
        elementType = attrs[typeAttribute]
        elementName = attrs[nameAttribute]
        (element,index) = elementType.gsub(/`/,"").split(/_/)
        # Only exons get numbered
        if(element == "Exon")
          elementName = index
        end
        elementType = element
        # If no color search by element type
        if(elementColor.nil?)
          elementColor = @colors[elementType]
        end
        # If that doesn't work go with black
        if(elementColor.nil? or elementColor !~ /#[a-fA-F0-9]{6}/ )
          elementColor = "#ffffff"
        end
        barArray << Bar.new(elementScore, elementColor, elementType, elementName)
      }
      times[:lffLines] += (Time.now.to_f - t1)
      t2 = Time.now.to_f
      # Handle negative strand genes
      if(elementStrand == '-')
        barArray = barArray.reverse
      end
      # max. score for scaling
      maxScore = barArray.map{ |bb| bb.score}.max
      bd = BarGlyphDrawer.new(barArray)
      bd.draw(imgName, 50, maxScore)
      times[:postAndDraw] += (Time.now.to_f - t2)
      #times.each_key { |kk| $stderr.puts "  #{kk} => #{times[kk]}" }
    end
  end
end; end; end # module BRL ; module Genboree ; module Graphics
