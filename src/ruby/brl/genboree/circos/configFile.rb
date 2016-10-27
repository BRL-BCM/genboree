#! /usr/bin/env ruby

########################################################################################
# Project: Circos UI Integration
#   This project creates a new User Interface (UI) to assist users in
#   creating parameter files for the Circos visualization program (v0.49).
#   The integration also creates a server-side support environment to create
#   necessary configuration files, queue a Circos job with the Genboree environment
#   and then package the Circos output files and notify the user of job completion.
#
# configFile.rb - This file represents circos configuration options and is 
#   responsible for doing some minor validation, creating the resulting conf file and 
#   inserting necessary default specs.
#
# NOTE - This circos UI server side implementation is not meant to take an already created
#   circos configuration file. This implementation assumes defaults. If a user has a 
#   complete circos configuration file, they should make their desired changes to the file
#   and then manually run the circos binary. This is not meant to be a circos runner script.
#
# Arguments:
# -o, --options (REQUIRED) : A JSON formatted object representing the Circos options (for drawing and running)
# -d, --daemonize (OPTIONAL): Run the coordinator in a daemonized mode (default when called from web)
#
# Developed by Bio::Neos, Inc. (BIONEOS)
# under a software consulting contract for:
# Baylor College of Medicine (CLIENT)
# Copyright (c) 2009 CLIENT owns all rights.
# To contact BIONEOS, visit http://bioneos.com
########################################################################################

require 'rubygems'
require 'json'
require 'brl/genboree/genboreeUtil'

########################################################################################
# Extend the Hash class to add a deepMerge method which will recursively merge 
# Hashes inside the circos options hash. This is required so that default ideogram 
# values are not blasted when merging in the passed circos UI ideogram options
#
# author: Michael F Smith (MFS), 12.18.09
########################################################################################
class Hash
  def deepMerge!(hash)
    hash.each_key { |key|
      if(self[key].is_a?(Hash) and hash[key].is_a?(Hash))
        self[key].deepMerge!(hash[key])
      else
        self[key] = hash[key]
      end
    }

    return self
  end
end

module BRL ; module Genboree ; module Circos

class ConfigFile < Hash
  @colors = nil
  @nextColorIndex = 0
  @nextLinkIndex = 0
  @colorsFile = ""
  @fontsFile = ""
  @maxTickLabelSize = 0

  def initialize(opts, defaultsFilePath=nil)
    genbConf = BRL::Genboree::GenboreeConfig.load()
    defFilePath = defaultsFilePath || genbConf.circosDefaultsFile
    raise RuntimeError.new("The defaults file does not exist! : \ndefaults file path: #{defFilePath}") unless (File.exists?(defFilePath))

    if(genbConf.circosInstallBase)
      @colorsFile = File.join(genbConf.circosInstallBase, "etc", "colors.conf")
      @fontsFile = File.join(genbConf.circosInstallBase, "etc", "fonts.conf")
    end
    
    @colors = Hash.new()
    @nextColorIndex = 1
    @nextLinkIndex = 1
    @maxTickLabelSize = 0
    
    # Load our defaults into the confFile options hash
    self.merge!(JSON.load(File.new(defFilePath, "r")))

    # Load our passed options for the Circos run
    self.deepMerge!(opts)
  end

  ###############################################################################
  # This method converts a hex based (web) color to a decimal RGB value
  # *Args* :
  # - +hexColor+ -> The hex based color to convert
  # *Returns* :
  # - +String+ -> A string representing the Red,Green,Blue values
  ###############################################################################
  def hexToRGB(hexColor)
    color = Array.new()
    convColor = ""

    begin
      # Strip off our '#' to make it easier to deal with
      hexColor = hexColor[1..(hexColor.length - 1)] if hexColor[0..0] == "#"
      hexColor = hexColor[0..0] * 2 + hexColor[1..1] * 2 + hexColor[2..2] * 2 if hexColor.length == 3
      color[0] = hexColor[0..1].to_i(16)
      color[1] = hexColor[2..3].to_i(16)
      color[2] = hexColor[4..5].to_i(16)

      convColor = color.join(',')
    rescue
      # An error occurred, so just return what was passed to us
      convColor = hexColor
    end

    return convColor
  end

  def addColor(color, colorName = nil)
    color = hexToRGB(color) if(!color.index("#").nil?)

    if(colorName.nil?)
      # If we are not a named color and the color exists, do not insert again, just return the name
      return @colors.index(color) if(@colors.has_value?(color))
        
      colorName = "color_#{@nextColorIndex}"
      @nextColorIndex += 1
    end
    @colors[colorName] = color
    
    return colorName
  end

  def generateColorString()
    allColors = ""
    @colors.each { |key, value|
      allColors << "#{key} = #{value}\n  "
    }

    return allColors
  end

  # This is a crude method for calculating the drawing width of the label
  def checkTickLabelSize(tickObj, eps)
    tickSpacing = tickObj["spacing"].gsub("u", "").to_i
    
    # Go through every entry point and determine the max characters for this tick mark
    eps.each { |epObj|
      # Label width = max chars * 0.75em + buffer space
      maxLabelChars = (epObj["length"] * tickObj["multiplier"].to_f).to_i.to_s.length() + tickObj["suffix"].length()
      labelWidth = ((maxLabelChars * (tickObj["label_size"].to_i) * 0.75) + 5).to_i
      
      # If this tick label is largest we have seen, set it as our new max for offset purposes
      @maxTickLabelSize = labelWidth if(labelWidth > @maxTickLabelSize)
    }
  end

  ###############################################################################
  # This method creates a string block representation of a tick mark for 
  # Circos to consume
  # *Args* :
  # - +tick+ -> The tick mark to create a representation of
  # *Returns* :
  # - +String+ -> A string representing the tick mark block
  ###############################################################################
  def createTickBlock(tick, chromUnits)
    tickString =  "  <tick>\n"
    Hash.new().merge!(self['tick_defaults']['marker_defaults']).deepMerge!(tick).each { |key, value|
      value << "p" if((key =~ /size/i) and !(value =~ /\d+p/))
      tickString << "    #{key} = #{value}\n"
    }
    tickString += "  </tick>\n"

    return tickString
  end

  def createHighlightBlock(track)
    highlightString = "  <highlight>\n"
    Hash.new().merge!(self['plots']['highlight']).deepMerge!(track['properties']).each { |prop, value|
      # Highlights do not need this property
      next if(prop == "type")
      
      # Print out our property/value pair, unless no value is set. This should not happen, but in case...
      highlightString << "    #{prop} = #{(prop.match(/color/i)) ? addColor(value) : value}\n" unless(value.nil? or value.to_s.empty?)
    }
    highlightString << "  </highlight>\n"
    highlightString << createRuleBlock(track['rules'])

    return highlightString
  end

  def createPlotBlock(track)
    max = min = nil
    plotString = "  <plot>\n"
    plotString << "    show = yes\n"
    Hash.new().merge!(self['plots'][track['properties']['type']]).deepMerge!(track['properties']).each { |prop, value|
      # Print out our property/value pair, unless no value is set. This should not happen, but check in case...
      if(value.nil? or value.to_s.empty? or prop == "axis" or prop =="axis_lines")
        next
      elsif(prop.match(/color/i))
        # Most colors will have a single value, but heatmaps will have a list of colors separated by commas
        value = value.split(",").map { |color| addColor(color) }.join(",")
      end

      plotString << "    #{prop} = #{value}\n"
    }
   
    if(track['properties']['min'].nil? or track['properties']['max'].nil?)
      File.foreach(track['properties']['file']) { |annot|
        value = annot.split(" ")[3].to_f
        min = value if(min.nil?)
        max = value if(max.nil?)

        if(min > value)
          min = value
        elsif(max < value)
          max = value
        end
      }
      
      unless(max.nil? || min.nil?)
        max = min * 2 if(max == min)
        plotString << "    min = #{min}\n"
        plotString << "    max = #{max}\n"
      end
    end

    # Check if our plot has an axis specified, if so, setup appropriatetly
    if(track['properties']['axis'] == "yes" and !track['properties']['axis_lines'].nil? and !max.nil? and !min.nil?)
      plotString << "    axis = yes\n"
      plotString << "    axis_color = #{self['plots']['axis_color']}\n"
      plotString << "    axis_thickness = #{self['plots']['axis_thickness']}\n"
      plotString << "    axis_spacing = #{((max - min) / track["properties"]["axis_lines"].to_f).ceil}\n"
    end

    # Add a background to all plots, except tiles
    plotString << "    background = #{(track["properties"]["type"] == "tile") ? "no" : "yes"}\n"
    plotString << "    background_color = #{self['plots']['background_color']}\n"
    plotString << "    background_stroke_color = #{self['plots']['background_stroke_color']}\n"
    plotString << "    background_stroke_thickness = #{self['plots']['background_stroke_thickness']}\n"
    plotString << createRuleBlock(track["rules"])
    plotString << "  </plot>\n"
    
    return plotString
  end

  def createLinkBlock(track)
    propsUnsupportedByCircos = ["linked_to", "linked_by", "type"]
    linkString = "  <link link_#{@nextLinkIndex}>\n"
    Hash.new().merge!(self['plots']['link']).deepMerge!(track['properties']).each { |prop, value|
       # Some properties we need for the UI integration are not supported by Circos, so we ignore them
       next if(propsUnsupportedByCircos.include?(prop))

       linkString << "    #{prop} = #{(prop.match(/color/i)) ? addColor(value) : value}\n" unless(value.nil? || value.to_s.empty?)
    }
    linkString << createRuleBlock(track["rules"])
    linkString << "  </link>\n"
    @nextLinkIndex += 1

    return linkString
  end

  def createRuleBlock(rules)
    return "" if(rules.nil? or rules.empty?)

    ruleString = "  <rules>\n"
    rules.each_with_index { |rule, index|
      ruleString << "    <rule>\n"
      ruleString << "      importance = #{index + 1}\n"
      rule.each { |prop, value|
        # Print out our property/value pair, unless no value is set. This should not happen, but in case...
        ruleString << "      #{prop} = #{(prop.match(/color/i)) ? addColor(value) : value}\n" unless(value.nil? || value.to_s.empty?)
      }
      ruleString << "    </rule>\n"
    }
    ruleString << "  </rules>\n"

    return ruleString
  end
 
  def generateConfFile(fileName=nil)
    begin
      configString = ""
      spacingString = ""
      epString = ""
      epLocalScales = ""
      epGlobalScales = ""
      highlightString = ""
      plotString = ""
      linkString = ""
      breakString = ""
      colorString = ""
      ticksString = ""

      # Set our spacing and break spaces
      if(self['ideogram']['closed'])
        spacingString << "    default = 0u\n"
        spacingString << "    break = 0u\n"
      else
        spacingString << "    default = #{self['ideogram']['spacing'].to_s + ((self['ideogram']['spacing'].to_s =~ /\d+u/) ? "" : "u")}\n"
        spacingString << "    break = #{self['break_defaults']['spacing']}\n"
      end

      # Create our entry points
      raise ArgumentError.new("No entry points were specified!") if (self['ideogram']['entry_points'].nil? or self['ideogram']['entry_points'].empty?)
      
      # Because of the way Circos implements colors for the ideogram, we CANNOT simply use an RGB value
      # for wherever we want a custom ideogram color, instead it must be a NAMED color.  So we build a 
      # string that represents our custom ideogram colors (note this might contain duplicate colors under
      # different names).  This is only required for the ideogram, annotation tracks support RGB colors...
      self['ideogram']['entry_points'].each { |ep|
        next if !ep['drawn']
        epString << "#{ep['id']};"
        addColor(ep['color'], "#{ep['id']}_color") unless(ep['color'].nil?)
        unless(ep['breaks'].nil?)
          ep['breaks'].each { |epBreak|
            breakString << "-#{ep['id']}:#{epBreak['start']/self['ideogram']['units']}-#{epBreak['end']/self['ideogram']['units']};"
          }
        end

        if(ep['scale'] == "global_scale" and ep['global_scale_factor'])
          epGlobalScales = "chromosomes_scale = " if(epGlobalScales.empty?)
          epGlobalScales << "#{ep['id']}:#{ep['global_scale_factor']};"
        elsif(ep['scale'] == "local_scale" and !ep['local_scales'].nil? and ep['local_scales'].length > 0)
          epLocalScales << "<zooms>\n"
          ep['local_scales'].each_value { |scaleObj|
            epLocalScales << "  <zoom>\n"
            epLocalScales << "    chr = #{ep['id']}\n"
            epLocalScales << "    start = #{(scaleObj['start'] / self['ideogram']['units'])}u\n"
            epLocalScales << "    end = #{(scaleObj['end'] / self['ideogram']['units'])}u\n"
            epLocalScales << "    scale = #{scaleObj['scale']}\n"
            epLocalScales << "  </zoom>\n"
          }
          epLocalScales << "</zooms>\n"
        end
      }
      addColor(self['ideogram']['color'], "global")

      # Construct our ticks block and add it to our ticks string
      unless(self['ticks'].nil?)
        self['ticks'].each { |tickMark|
          if(tickMark['show_tick'])
            ticksString << createTickBlock(tickMark, self['ideogram']['units'])
            checkTickLabelSize(tickMark, self['ideogram']['entry_points']) if(tickMark['show_label'])
          end
        }
      end

      # Create our blocks for annotation tracks
      # tracks = {"track:name" => [{<track params inst. 1}, {<track params inst. 2}], "track2:name" => [{<track 2 params inst1}]}
      unless(self['tracks'].nil? or self['tracks'].empty?)
        plots = Array.new()
        highlights = Array.new()
        links = Array.new()

        self['tracks'].each_value { |track|
          track.each { |trackInstance|
            next if trackInstance['properties'].nil?

            type = trackInstance['properties']['type']
            if(type == "highlight")
              highlights.push(createHighlightBlock(trackInstance))
            elsif(type == "link")
              links.push(createLinkBlock(trackInstance))
            elsif(["scatter", "line", "histogram", "tile", "heatmap"].include?(type))
              plots.push(createPlotBlock(trackInstance))
            end
          }
        }

        highlightString << "<highlights>\n  #{highlights.join("\n  ")}</highlights>" if(highlights.length > 0)
        plotString << "<plots>\n#{plots.join("\n")}</plots>" if(plots.length > 0)
        linkString << "<links>\n#{links.join("\n")}</links>" if(links.length > 0)
      end

      configString << "
#Include our color and font files
<colors>
  #{"<<include " + @colorsFile + ">>" if(File.exists?(@colorsFile))}
  #{generateColorString()}
</colors>
<fonts>
  #{"<<include " + @fontsFile + ">>" if(File.exists?(@fontsFile))}
</fonts>

<ideogram>
  <spacing>
    #{spacingString}

    # Break style information
    axis_break_at_edge = #{self['break_defaults']['axis_break_at_edge']}
    axis_break         = #{(self['ideogram']['closed']) ? "no" : "yes"}
    axis_break_style   = #{self['ideogram']['axis_break_style']}

    <break_style 1>
      stroke_color = #{self['break_defaults']['styles']['1']['stroke_color']}
      fill_color   = #{self['break_defaults']['styles']['1']['fill_color']}
      thickness    = #{self['break_defaults']['styles']['1']['thickness']}
      stroke_thickness = #{self['break_defaults']['styles']['1']['stroke_thickness']}
    </break>

    <break_style 2>
      stroke_color     = #{self['break_defaults']['styles']['2']['stroke_color']}
      stroke_thickness = #{self['break_defaults']['styles']['2']['stroke_thickness']}
      thickness        = #{self['break_defaults']['styles']['2']['thickness']}
    </break>
  </spacing>

  # thickness (px) of chromosome ideogram
  # Use a relative thickness - relative the ideogram radius
  thickness        = #{self['ideogram']['thickness']}
  stroke_thickness = #{self['ideogram']['stroke_thickness']}
  # ideogram border color
  stroke_color     = #{self['ideogram']['stroke_color']}
  fill             = #{self['ideogram']['fill']}
  # the default chromosome color is set here and any value
  # defined in the karyotype file overrides it - use our custom
  # defined global color here...
  fill_color       = global

  # fractional radius position of chromosome ideogram within image
  radius         = #{self['ideogram']['radius_pos']}
  show_label     = #{self['ideogram']['show_label']}
  label_with_tag = #{self['ideogram']['label_with_tag']}
  label_font     = #{self['ideogram']['label_font']}
  label_radius   = dims(ideogram,radius) + 0.1r + #{@maxTickLabelSize}p
  label_center   = #{self['ideogram']['label_center']}
  # Keep the label size a ratio of the default propeties 
  # TODO - Calculate this off of a default label size / default ideogram radius?
  label_size     = #{(0.032 * self['ideogram']['radius'].to_f).to_i}p

  # cytogenetic bands
  band_stroke_thickness = #{self['ideogram']['band_stroke_thickness']}

  # show_bands determines whether the outline of cytogenetic bands will be seen
  show_bands            = #{self['ideogram']['show_bands']}
  # in order to fill the bands with the color defined in the karyotype file you must set fill_bands
  fill_bands            = #{self['ideogram']['fill_bands']}
</ideogram>

chrticklabels       = #{self['circos_defaults']['chrticklabels']}
chrticklabelfont    = #{self['circos_defaults']['chrticklabelfont']}

show_ticks          = #{self['circos_defaults']['show_ticks']}
show_grid           = #{self['circos_defaults']['show_grid']}
show_tick_labels    = #{self['circos_defaults']['show_tick_labels']}
<ticks>
  tick_separation   = #{self['tick_defaults']['tick_separation']}
  label_separation  = #{self['tick_defaults']['label_separation']}
  label_offset      = #{self['tick_defaults']['label_offset']}
  radius            = #{self['tick_defaults']['radius']}

  #{ticksString}
</ticks>

karyotype   = #{self['karyotype_file_path']}

<image>
  dir = #{self['tmp_results_dir']}
  file  = #{self['image_name']}
  # radius of inscribed circle in image
  radius         = #{self['ideogram']['radius']}p
  background     = #{self['circos_defaults']['background']}
  # by default angle=0 is at 3 o'clock position
  angle_offset   = -90
</image>

chromosomes_units = #{self['ideogram']['units']}
chromosomes       = #{epString}
chromosomes_breaks = #{breakString unless(breakString.empty?)}
chromosomes_display_default = #{self['circos_defaults']['chromosomes_display_default']}
#{epLocalScales unless(epLocalScales.empty?)}
#{epGlobalScales unless(epGlobalScales.empty?)}

#{highlightString unless(highlightString.empty?)}
#{plotString unless(plotString.empty?)}
#{linkString unless(linkString.empty?)}

anglestep       = 0.5
minslicestep    = 10
beziersamples   = 40
debug           = #{self['circos_defaults']['debug']}
warnings        = #{self['circos_defaults']['warnings']}
imagemap        = #{self['circos_defaults']['imagemap']}

# Do not touch!
units_ok = bupr
units_nounit = n
    "

      if(!fileName.nil?)
        file = File.new(fileName, "w")
        file << configString
        file.close()
      end

      return configString
    rescue => e
      err = "There was an error "
      if(fileName.nil?)
        err << "creating the Circos configuration string"
      else
        err << "saving the Circos configuration file to #{fileName}"
      end
      raise RuntimeError.new("#{err}!\n#{e}\n#{e.backtrace.join("\n ")}")
    end
  end
end

end ; end; end
