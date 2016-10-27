require 'json'

module BRL; module Genboree
class GenericHighchart

  # --------------------------------------------------
  # Public methods
  # --------------------------------------------------

  # @return ["column", "line", "pie"] the type of chart
  attr_accessor :type
  # @return [Array<String>] the xAxis labels
  attr_accessor :xAxis
  # @return [String] the yAxis label
  attr_accessor :yAxis
  # @return [Fixnum] desired minimum value for the yAxis (optional)
  attr_accessor :yMin
  # @return [Fixnum] desired max value for the yAxis (optional)
  attr_accessor :yMax
  # @return [Boolean] false if whole number tick marks are desired for the yAxis
  # @note analagous setting exists in highcharts for the xAxis but is not exposed here
  attr_accessor :allowDecimals
  # @return [String] the chart title
  attr_accessor :title
  # @return [Hash, Array] @see collectDataSeries
  attr_accessor :data
  # @return [Array<String>] the names of the data series
  attr_accessor :seriesNames
  # @return ["log", "linear", "auto"] the yAxis scale to use
  attr_accessor :scale
  # @return [String] the units to display in the tooltip for points, column, slice, etc. 
  #   in the chart
  attr_accessor :units
  
  # @todo named arguments?
  def initialize
    # apply default values
    @scale = "auto"
  end

  def clear
    @type = @xAxis = @yAxis = @title = @data = @seriesNames = @scale = @units = @yMin = nil
    @yMax = @allowDecimals = nil
  end

  # Retrieve Highchart template for the specified type -- data from the object instance will
  #   not be used to populate the chart config
  # @param ["column", "pie", "line"] type the type of chart
  # @return [Hash] chart template for column or pie type
  # @note this can be extended to incorporate other types as well in future.
  def getChartTemplate(type=@type)
    chart = {}
    if(type == 'column')
      chart = getColumnChartTemplate
    elsif(type == 'pie')
      chart = getPieChartTemplate
    elsif(type == 'line')
      chart = getLineChartTemplate
    else
      raise "Error, INVALID type: #{type}"
    end
    return chart
  end

  # @see e.g. getChartTemplate -- data from the object instance WILL be used to populate 
  #   the chart config
  def fillChartTemplate(type=@type)
    chart = {}
    if(type == "column")
      chart = fillColumnChartTemplate
    elsif(type == "pie")
      chart = fillPieChartTemplate
    elsif(type == "line")
      chart = fillLineChartTemplate
    else
      raise "Invalid chart type #{type}"
    end
    return chart
  end

  # --------------------------------------------------
  # COLUMN CHART FUNCTIONS
  # --------------------------------------------------

  # @see getChartTemplate
  def getColumnChartTemplate
    chart = {
      # common parts
      "credits" => { "enabled" => false },
      "title" => { 
        "text" => "",
        "style" => {
          "fontSize" => "13px"
        },
        "margin" => 9
      },
      "xAxis" => {
        "categories" => []
      },
      "yAxis" => {
        "title" => { "text" => "" }
      },
      "series" => [
        {
          "name" => "",
          "data" => []
        }
      ],
      "navigation" => {
        "buttonOptions" => { 
          "enabled" => true, 
          "align" => "right", 
          "verticalAlign" => "top", 
          "symbolSize" => 11,
          'symbolStrokeWidth' => 1
        }
      },

      # specific parts
      "chart" => { 
        "type" => "column", 
        "spacingLeft" => 2, 
        "spacingRight" => 2,
        "spacingBottom" => 2,
        "spacingTop" => 2 
      },
      "plotOptions" => {
        "column" => {
          "minPointLength" => 2,
          "dataLabels" => {"enabled" => false}
        }
      },
      
      "tooltip" => {
        "pointFormatter" => getPointFormatter(),
        "headerFormat" => "<span style=\"font-size: 10pt\"><b>{point.key}</b></span><br/>"
      }
    }
    return chart
  end

  # Unless a specific order is given, order the columns by 
  #   (1) their height descending (max of all series)
  #   (2) case-insensitive name
  #   (3) case-sensitive name
  # @see fillLineChartTemplate
  def fillColumnChartTemplate
    template = getColumnChartTemplate
    noOrderGiven = @xAxis.nil?
    template['series'] = collectDataSeries
    if(noOrderGiven and !@xAxis.nil?)
      # then we have xAxis data from collectDataSeries and we can sort as described
      xAxis = @xAxis
      data = template["series"].collect{|xx| xx["data"]}
      # [[ xAxisLabelA, series1Value, series2Value, ... ],
      #  [ xAxisLabelB, series1Value, series2Value, ... ],
      #  ...
      # ]
      objsToSort = xAxis.zip(*data)
      objsToSort.sort!{|obj1, obj2|
        xAxis1 = obj1[0]
        xAxis2 = obj2[0]
        maxColumnValue1 = obj1[1..-1].map{|xx| xx.to_f}.max
        maxColumnValue2 = obj2[1..-1].map{|xx| xx.to_f}.max
        retVal = (maxColumnValue2 <=> maxColumnValue1) # descending order
        retVal = (xAxis1.downcase <=> xAxis2.downcase) if(retVal == 0)
        retVal = (xAxis1 <=> xAxis2) if(retVal == 0)
        retVal
      }
      @xAxis = objsToSort.collect{|xx| xx[0]}
      template["series"].each_index { |seriesIdx|
        # +1 because xAxisLabel comes first
        template["series"][seriesIdx]["data"] = objsToSort.collect{|xx| xx[seriesIdx + 1]}
      }
    end
    fillCommonSettings(template) # collectDataSeries may help with settings

    scale = applyScale!(template, @scale)
    if(scale == "log")
      # re set data series values to protect against log 0 and modify tooltip accordingly
      template = prepareTemplateForLog(template)
    else
      template = prepareTemplateForLinear(template)
    end

    return template
  end

  # --------------------------------------------------
  # PIE CHART FUNCTIONS
  # --------------------------------------------------

  # @see getChartTemplate
  def getPieChartTemplate
    chart = {
      # common parts (pie is pretty weird versus the others)
      "credits" => { "enabled" => false },
      "title" => {
        "text" => "",
        "style" => {
          "color" => "#333333",
          "fontSize" => "13px"
        }
      },
      "series" => [
        {
          "type" => "pie", # note type difference
          "name" => "",
          "data" => [] # also note data goes here rather than in series
        }
      ],
      "navigation" => {
        "buttonOptions" => { 
          "enabled" => true, 
          "align" => "right", 
          "verticalAlign" => "top", 
          "symbolSize" => 11,
          'symbolStrokeWidth' => 1
        }
      },
      # specific parts
      "chart" => {
        "plotBackgroundColor" => nil,
        "plotBorderWidth" => 1,
        "plotShadow" => false
      },
      "tooltip" => {  
        "pointFormat" => "{series.name}: <b>{point.percentage:.1f}%</b>" ,
        "headerFormat" => "<span style=\"font-size: 12px\"><b>{point.key}</b></span><br/>"
      }
    }
    return chart
  end

  # Fill in config for a simple line chart
  # @param [Hash<Symbol, Object>] @see fillLineChartTemplate
  #   [String] :title the chart title
  #   [Array<String>] :xAxis aka :series (latter preferred) the names of data slices in pie
  #     @todo perhaps confusingly named for pie but not for others
  #   [String] :units measurement unit for data points tooltip
  #   [Hash, Array] :data 
  #     if Hash, a mapping of xAxis name to its value (overriding xAxis/series option)
  #     if Array, parallel to xAxis names
  # @return [Hash] @see getPieChartTemplate (values now filled in)
  def fillPieChartTemplate(data=@data, xAxis=@xAxis)
    template = getPieChartTemplate()
    # pie chart has a different set of options versus charts with axes (line, column, etc.)
    template['title']['text'] = @title if(!@title.nil?)
    template['series'][0]['name'] = @units if(!@units.nil?)
    series = xAxis if(@series.nil?)

    # fill series for Highcharts:
    #   series: [ {"type" => 'pie', "name" => 'Title', "data" => [ ["key1", 1.0], ["key2", 2.0] ], ... } ]
    if(data.is_a?(Hash))
      template['series'][0]['data'] = data.collect{|avp| avp}
    elsif(data.is_a?(Array))
      raise ArgumentError.new("Missing data slice names in named parameter :series") if(@series.nil?)
      raise ArgumentError.new("Data size #{data.size} does not match series size #{@series.size}") if(@series.size != data.size)
      data = []
      data.each_index { |ii| data << [@series[ii], data[ii]] }
      template['series'][0]['data'] = data
    else
      raise ArgumentError.new("Unsupported data class #{data.class}")
    end
    return template
  end

  # --------------------------------------------------
  # LINE CHART FUNCTIONS
  # --------------------------------------------------

  # Create a single line graph
  # @see getChartTemplate
  def getLineChartTemplate
    chart = {
      # common parts
      "credits" => { "enabled" => false },
      "title" => { 
        "text" => "",
        "style" => {
          "fontSize" => "13px"
        }
      },
      "xAxis" => {
        "categories" => []
      },
      "yAxis" => {
        "title" => { "text" => "" }
      },
      "navigation" => {
        "buttonOptions" => { 
          "enabled" => true, 
          "align" => "right", 
          "verticalAlign" => "top", 
          "symbolSize" => 11,
          'symbolStrokeWidth' => 1
        }
      },
      "chart" => { 
        "spacingLeft" => 2, 
        "spacingRight" => 2,
        "spacingBottom" => 2,
        "spacingTop" => 2 
      },
      "series" => [
        {
          "name" => "",
          "data" => []
        }
      ],

      # specific parts
      "tooltip" => {
        "pointFormatter" => getPointFormatter(),
        "headerFormat" => "<span style=\"font-size: 10pt\"><b>{point.key}</b></span><br/>"
      }
    }
    return chart
  end

  # Fill in config for a simple line chart
  # @return [Hash] @see getLineChartTemplate (values now filled in)
  def fillLineChartTemplate
    template = getLineChartTemplate()

    # unique line chart settings
    template['tooltip']['valueSuffix'] = @units unless(@units.nil?)
    
    template['series'] = collectDataSeries()
    fillCommonSettings(template) # collectDataSeries helps with settings

    scale = applyScale!(template, @scale)
    if(scale == "log")
      # re set data series values to protect against log 0 and modify tooltip accordingly
      template = prepareTemplateForLog(template)
    else
      template = prepareTemplateForLinear(template)
    end

    return template
  end

  # --------------------------------------------------
  # @data UTILITIES
  # Collection of xAxis and seriesName labels from @data and preparation of 
  #   that data in the template
  # --------------------------------------------------
  
  # Provide common input type for at least column and line charts
  # @param [Hash, Array] :data 
  #   if Hash, a mapping of xAxis name to its value
  #   if Array, parallel to xAxis names
  #   if Array<Hash>, multiple series with series names from :series, :xAxis is required
  #   if Array<Array>, ''
  #   if Hash<Array>, series names as keys to series values, :xAxis is required
  #   if Hash<Hash>, '' :xAxis or key order of first Hash sets x axis order (you should be 
  #     using an OrderedHash object in this case most probably)
  # @note sets @seriesNames if nil
  # @note sets @xAxis if nil and data permits
  # @todo how to apply series name override given collectHashSeries and collectArraySeries
  def collectDataSeries(data=@data, xAxis=@xAxis)
    # prepare Array of Hash for Highcharts for a variety of input types:
    #   series: [ { name: "Series1", data: [1,2,3] }, ... ]
    series = []
    if(data.empty?)
      series = []
    elsif(data.is_a?(Hash))
      avp = data.first
      vv = avp[1]
      if(vv.is_a?(Hash))
        series = collectHashSeries(data, xAxis)
      elsif(vv.is_a?(Array))
        series = collectArraySeries(data, xAxis)
      else
        series = (@seriesNames.nil? ? ["Series 1"]  : @seriesNames)
        xAxis = data.keys if(xAxis.nil?)
        @xAxis = xAxis if(@xAxis.nil?)
        data = xAxis.map { |key| 
          raise ArgumentError.new("Series #{series.first.inspect} size #{data.values.size} does not match the size of the x axis #{xAxis.size}") if(data.values.size != xAxis.size)
          data[key] 
        }
        series = [ { "name" => series.first, "data" => data } ]
      end

    elsif(data.is_a?(Array))
      vv = data.first
      if(vv.is_a?(Hash))
        if(series.empty?)
          series = []
          data.each_index { |ii| series << "Series #{ii+1}" }
        end
        series = collectHashSeries(data, xAxis)
      elsif(vv.is_a?(Array))
        if(series.empty?)
          series = []
          data.each_index { |ii| series << "Series #{ii+1}" }
        end
        series = collectArraySeries(data, xAxis)
      else
        series = ["Series 1"] if(series.nil?)
        raise ArgumentError.new("Missing :xAxis!") if(xAxis.nil?)
        series = [ { "name" => series.first, "data" => data } ]
      end
    end

    # dont display label for just one series
    if(series.size == 1)
      series.first['showInLegend'] = false
    end

    return series
  end

  # Utility function for @see fillLineChartTemplate
  # prepare Array of Hash for Highcharts for Hash data:
  #   series: [ { name: "Series1", data: [1,2,3] }, ... ]
  # which may possibly override the existing value for @series if it does not
  #   agree with @data
  def collectHashSeries(data=@data, xAxis=@xAxis)
    retVal = []
    series = []
    if(@seriesNames.nil? or @seriesNames.size != data.size or !@seriesNames.is_a?(Array))
      # then @seriesNames is not correctly set, use implicit series from the data
      seriesLabels = data.keys 
    else
      # otherwise we can use the series names that were provided
      seriesLabels = @seriesNames
    end
    xAxis = data.first[1].keys if(xAxis.nil?)
    ii = 0
    data.each_key { |seriesName|
      if(data[seriesName].values.size != xAxis.size)
        raise ArgumentError.new("Series #{seriesName.inspect} size #{data[seriesName].values.size} does not match the size of the x axis #{xAxis.size}") 
      end
      configData = xAxis.map { |key| data[seriesName][key] }
      seriesLabel = seriesLabels[ii]
      retVal << { "name" => seriesLabel, "data" => configData }
      ii += 1
    }
    return retVal
  end

  # Utility function for @see fillLineChartTemplate
  # prepare Array of Hash for Highcharts for Array data:
  #   series: [ { name: "Series1", data: [1,2,3] }, ... ]
  def collectArraySeries(data=@data, xAxis=@xAxis)
    series = []
    series = data.keys if(@seriesNames.nil? or @seriesNames.size != data.size or !@seriesNames.is_a?(Array))
    raise ArgumentError.new("xAxis labels must be provided for this type of input") if(xAxis.nil?)
    n_values = data[series.first].size
    series = series.map { |seriesName| 
      raise ArgumentError.new("Series #{seriesName.inspect} size #{data[seriesName].size} does not match the size of the x axis #{xAxis.size}") if(data[seriesName].size != xAxis.size)
      { "name" => seriesName, "data" => data[seriesName] } 
    }
    return series
  end

  # --------------------------------------------------
  # @yAxis UTILITIES
  # Functions related to linear or logarithmic yAxis scaling
  # --------------------------------------------------

  # Get base-10 fold change of data to help determine if base 10 logarithmic yAxis scaling is appropriate
  # @param [Array] data the data to get the fold change for, elements must respond to to_f
  #   and be positive
  def foldChange(data)
    delta = 0
    data = data.map{|xx| xx.to_f.abs}
    posData = data.select{|xx| xx != 0}
    min = posData.min
    max = posData.max
    if(min and max)
      delta = (Math.log10(max) - Math.log10(min)).to_i
    end
    return delta.to_i
  end

  # Apply yAxis scale settings to the template
  # @param [Hash] template the chart template (must be of type :line or :column)
  # @param [String] scale see @scale
  # @return [String] scale the chosen scale
  # @note zero values will be left intact
  # @todo combine this with mutateZeros! in a better way
  def applyScale!(template, scale=@scale)
    # @note scale check must occur after setting of @xAxis
    scale = @scale
    if(scale == "auto")
      # then modify scale to log or linear
      scale = "linear"
      anyNegative = false
      template["series"].each{|series|
        data = (series["data"] ? series["data"] : [])
        data.each{|xx|
          if(xx < 0)
            scale = "linear"
            anyNegative = true
            break
          end
        }
      }
      unless(anyNegative)
        template["series"].each{|series|
          data = (series["data"] ? series["data"] : [])
          if(foldChange(data) > 2)
            scale = "log"
            break
          end
        }
      end
    end
    if(scale == "log")
      template['yAxis']['type'] = "logarithmic"
    end
    # else linear is the default

    return scale
  end

  # Since we cannot return a function in JSON we return a function body intended
  #   for use in JS: new Function(arg1, arg2, ..., functionDefStr). We provide
  #   different point formatters for different yAxis scalings
  # @param [String] scale either "log" or "linear": @see @scale
  # @todo how to best organize this? JS source in my ruby source?? :(
  #   might be hard to find later
  # @note backslashes must be escaped once for the ruby string literal here and once 
  #   for their intended use as a javascript string literal
  def getPointFormatter(scale="linear")
    pointFormatterFnBody = ""
    if(scale == "log")
      pointFormatterFnBody = <<EOS
// make special value 0.1 appear as 0 as workaround to log 0 == undefined
var yy = this.y ;
if(yy == 0.1) {
  yy = 0 ;
}
// replace white-space-delimited numbers with ","-delimited ones
return '# '+this.series.name+': <b>'+ yy.toString().replace(/\\\\B(?=(\\\\d{3})+(?!\\\\d))/g, ",")+'</b>';
EOS
    else
      pointFormatterFnBody = <<EOS
return '# ' + this.series.name + ': <b>' + this.y.toString().replace(/\\\\B(?=(\\\\d{3})+(?!\\\\d))/g, ",") + '</b>';
EOS
    end
    return pointFormatterFnBody
  end

  # Utility function intended for use with logarithmically scaled line charts
  # @param [Object] data @see collectDataSeries
  # @return [Boolean] true if any values were mutated
  # @todo perhaps this should map <=0 to 0.1?
  def mutateZeros!(data=@data)
    anyMutated = false
    zeroFn = Proc.new { |vv|
      if(vv == 0)
        anyMutated = true
        0.1
      else
        vv
      end
    }
    BRL::Util::dfs!(data, zeroFn)
    return anyMutated
  end

  # Analagous settings to @see prepareTemplateForLog:
  #   set yAxis min, max
  # @param [Hash] template @see getChartTemplate
  # @return [Hash] @see getChartTemplate
  def prepareTemplateForLinear(template)
    if(@allowDecimals == false)
      template["yAxis"]["allowDecimals"] = false
    end
    if(@yMin)
      template["yAxis"]["min"] = @yMin
      template["yAxis"]["startOnTick"] = false
    end
    if(@yMax)
      template["yAxis"]["max"] = @yMax
    end
    return template
  end

  # Common functions for protecting template for highcharts log scaling: 
  #   set yAxis min, max, major tick positions, tooltip, tick labels
  # @note this function addresses a few stylistic goals:
  #   (1) charts which display data for "whole" entities should not display any fractions --
  #     there is no such thing as a 1/2 kbDoc for example
  #   (2) a minimum yAxis value @yMin should be settable through this class
  #   Together these goals cannot be addressed by the intuitive config "yAxis.min", consider
  #     http://jsfiddle.net/ab40/axjLz68s/
  #   where the minimum is overridden; yAxis.min can be enforced with yAxis.startOnTick=false,
  #   but then whether or not the first tick is on the axis depends on the data as in these examples:
  #     http://jsfiddle.net/ab40/vkc60qag/
  #     http://jsfiddle.net/ab40/74uaxf6p/
  #   which causes undesirable behavior for the yAxis labels. 
  #   yAxis.floor does not seem to respect negative values (for log it is powers of 10):
  #     http://jsfiddle.net/ab40/an2v50gn/ # negative
  #     http://jsfiddle.net/ab40/4dLrzyos/ # positive
  #   yAxis.allowDecimals also does not work to achieve (1) probably because it behaves differently
  #     for yAxis.type=logarithmic
  #   It appears that a combination of min, max, and minTickInterval are able to meet the goals
  def prepareTemplateForLog(template)
    anyMutated = mutateZeros!(@data)
    if(anyMutated)
      # apply artificial floor only if input data was mutated, update chart with artifical floor
      template['series'] = collectDataSeries()
      template["tooltip"]["pointFormatter"] = getPointFormatter("log")
    end
    template["minTickInterval"] = 1
    min, max = getLogMinAndMax()
    template["yAxis"]["min"] = min.to_f
    template["yAxis"]["max"] = max.to_f
    template["yAxis"]["minTickInterval"] = 1
    if(@allowDecimals == false and min < 1)
      template["yAxis"]["showFirstLabel"] = false
    end

    return template
  end

  # Get suitable minimum and maximum to address goals described in @see #prepareTemplateForLog
  # @param [Object] data #see collectDataSeries
  # @param [Fixnum] min @see #yMin
  # @param [Fixnum] max @see #yMax
  # @return [Array] min, max for use as yAxis configs
  def getLogMinAndMax(data=@data, min=@yMin, max=@yMax)
    # determine min and max of the data
    unless(min and max)
      procMax = 0
      procMin = (2**(0.size * 8 -2) -1) # Fixnum max (before Bignum)
      rangeFn = Proc.new { |xx|
        if(xx.respond_to?(:>) and xx > procMax)
          procMax = xx
        end
        
        if(xx.respond_to?(:<) and xx < procMin)
          procMin = xx
        end
        [procMin, procMax]
      }
      BRL::Util::dfs(data, rangeFn) # sets max, min via closure
      min = min.nil? ? procMin : min
      max = max.nil? ? procMax : max
    end
    min = min.to_f
    max = max.to_f
    # default min and max is to span 5 powers
    min = min <= 0 ? 0.1 : min
    max = max <= 0 ? 10 ** 3 : max

    # round min down to the next power of 10, round max up to next power of 10
    min = 10 ** Math.log10(min).floor
    max = 10 ** Math.log10(max).ceil

    return [min, max]
  end

  # --------------------------------------------------
  # UTILITIES
  # --------------------------------------------------

  # Modify template with common options - does not apply to pie template but does apply at 
  #   least to column and line
  # @param [Hash] template @see getChartTemplate
  # @todo allow native JSON types on xAxis? currently number is converted to string, for example
  def fillCommonSettings(template)
    template['title']['text'] = "<b>#{@title}</b>"
    template['xAxis']['categories'] = @xAxis.map{|xx| xx.to_s}
    template['yAxis']['title']['text'] = @yAxis
  end

  # Simple attribute, value pair hashes are naturally represented as pie, column, etc. charts
  # @param [Hash] hh a simple avp hash
  # @param ["column", "pie"] type the type of chart to create
  def fillChartTemplateWithHash(hh, type=@type)
    raise ArgumentError.new("Could not determine chart template type") if(type.nil?)
    template = getChartTemplate(type)
    if(type == "pie")
      data = hh.collect{|avp| avp }
      template['series'][0]['data'] = data
    elsif(type == 'column')
      data = []
      names = []
      hh.each_key{|kk|
        data << hh[kk]
        names << kk
      }
      template['series'][0]['data'] = data
      template['xAxis']['categories'] = names
    else
      raise ArgumentError.new("Unsupported chart type")
    end
    return template
  end

  # Transform JSON string to JS object string; improves html source code readability
  #   and reduces client-side JSON parsing
  # @param [String] json 
  # @return [String] an associated JS object for source code
  def jsonToJsObj(json)
    jsStr = ""
    pattern = /\"([^\"]+)\":/
    json.each_line { |line|
      matchData = pattern.match(line)
      if(matchData)
        jsStr << line.gsub(matchData[0], matchData[1] + ":")
      else
        jsStr << line
      end
    }
    return jsStr
  end
end

# this class is specific to transformation documents
# @todo move this class somewhere else because it is very specific to transforms
class GbHighChart < GenericHighchart

  def initialize(dataHash, type, scale='linear', transformedData=false) 
    @dataHash = dataHash
    @type = type
    @scale = (scale == 'log') ? scale : 'linear'
    @transformedData = transformedData
    raise ArgumentError, "ERROR: #{scale} scale is not supported for the type #{@type}." if(@scale == 'log' and @type == 'pie')
  end

  ###################################
  # KB TRANSFORM SPECIFIC FUNCTIONS #
  ###################################

  # gets the data from a KB transformed json obj
  # @return [Array<Array>] NxM array of arrays, where N and M are rows and columns resp.
  def getData()
    data = Array.new()
    data = fetchDataRec(@dataHash['Data'], data)
    data.delete([])
    return data
  end

  # fills the template with respect to the partitions and data for
  # the transformed KB document
  # for type column 'log' scale is supported, default being 'linear'
  # @return [String] template, filled with appropriate values for type, data, axis valuesa and so on...
  def fillTemplate()
    part = getPartitionsAndMetadata()
    template = getChartTemplate()
    if(@transformedData)
      data = getData()
      if(@type == 'column')
        template['xAxis']['categories'] = part.last()
        names = part.first()
        data.each_with_index{ |dat, ii|
          template['series'][ii] = {"name" => names[ii], "data" => dat}
        }
      elsif(@type == 'pie')
        piedata = []
        names = part.last()
        data.first.each_with_index{|dat, ii|
          piedata << [names[ii], dat]     
        }
        template['series'][0]['data'] = piedata
      end
    end
    return template
  end


  # gets the data from json obj recursively.
  # by default data array has NXM dimension, where N is the set of last partition and M the first partition
  # @param [Array<Hash>] conData the main Data object of the transformed json object
  # @param [Array<Array>] allValues data values of each recursion is stored in this array, is empty at first recursion
  # @return [<Array<Array>] allValues full list of each data list
  def fetchDataRec(conData, allValues)
    val = []
    conData.each_with_index{|level, ii|
      if(level.key?('cell'))
        value  = level['cell']['value']
        value = value.chomp('%').to_i if(value.is_a?(String))
        val << value
      end
      allValues << val if(ii == conData.length - 1)
      allValues = fetchDataRec(level['data'], allValues) if(level.key?('data'))
      }
    return allValues
  end
  
  # gets the list of all partitions and metadata from the transformed data
  # @return [Array<Array>] partitions row and column levels
  # @return [Array<Array>] metadata for each partition element
  def getPartitionsAndMetadata()
    partitions = Array.new()
    tmpName = Array.new()
 
   #First partition 
    level = @dataHash['Data']
    level.each{ |item| 
      tmpName << item['name'] 
   }
    partitions << tmpName

    while(level.first.key?('data'))
     tmpName = []
     level = level.first['data']
     level.each{ |item| 
       tmpName << item['name']
     }
      partitions << tmpName
    end
    return partitions
  end

end
end; end
