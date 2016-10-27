#!/usr/bin/env ruby
require 'uncharted_ruby'
require 'json'
include Uncharted

#need a graphic class with xsize, ysize, scale, barGap, xLegend, yLegend, graphic title, institutionName
xSize = 1400
ySize = 800
scale = 0.45
barGap = 0.5
fileName = 'metrics.png'
xLegend = 'Centers'
yLegend = 'Percentage'
graphTitle = 'Metrics'
institution = Array.new(["BCM", "Broad", "WU"])

baseDir="/usr/local/brl/local/apache/htdocs/webapps/java-bin/TCGA-Reporting/"
projectName = ARGV[0]
jsonFileName= ARGV[1]
#fullJsonPath = "#{baseDir}#{projectName}/data/#{jsonFileName}"
fullJsonPath = ARGV[1]
fileName = ARGV[2]

##### TODO Need a dataSet class with an data(array), colorName(string) name(string)

averageData = JSON.parse(File.read(fullJsonPath))
bcmAverages = averageData["bcm"]
broadAverages = averageData["broad"]
wuAverages = averageData["wu"]

 


#################################

bcm = bcmAverages["sampleAverage"].to_f
broad = broadAverages["sampleAverage"].to_f
wu = wuAverages["sampleAverage"].to_f

dataSet1Data = Array.new([bcm, broad, wu])
dataSet1ColorName = 'orchid'
dataSet1Name = 'Average Sample Completion'

bcm = bcmAverages["geneAverage"].to_f
broad = broadAverages["geneAverage"].to_f
wu = wuAverages["geneAverage"].to_f

dataSet2Data = Array.new([bcm, broad, wu])
dataSet2ColorName = 'orange'
dataSet2Name = 'Average Gene Completion'

bcm = bcmAverages["ampliconAverage"].to_f
broad = broadAverages["ampliconAverage"].to_f
wu = wuAverages["ampliconAverage"].to_f

dataSet3Data = Array.new([bcm, broad, wu])
dataSet3ColorName = 'blue'
dataSet3Name = 'Average Amplicon Completion'

bcm = bcmAverages["1x"].to_f
broad = broadAverages["1x"].to_f
wu = wuAverages["1x"].to_f

dataSet4Data = Array.new([bcm, broad, wu])
dataSet4ColorName = 'brown'
dataSet4Name = 'Average 1X Gene Coverage'

bcm = bcmAverages["2x"].to_f
broad = broadAverages["2x"].to_f
wu = wuAverages["2x"].to_f

dataSet5Data = Array.new([bcm, broad, wu])
dataSet5ColorName = 'green'
dataSet5Name = 'Average 2X Gene Coverage'


#TODO This become a method!!

xSize *= scale
ySize *= scale
barGap *= scale
fontName = Uncharted::Config.getDefaultFontFilename() * scale
fontSize = Uncharted::Config.getDefaultFontSize() * scale
xTickLabels = StringVector.new(institution)
## Modify title font size
fontSizeMultiplier = 2.0 * scale
Uncharted::Config.setDefaultTitleFontSizeMultiplier(fontSizeMultiplier)
# Create (x,y) chart.
chart = XYChart.new('Legend onRight', xLegend, yLegend )


# Create offscreen buffer containing chart.
offscreen = OffscreenBuffer.new(xSize, ySize, chart)

# Set chart area fill.
chart.setChartAreaFill(GradientFill.new(Color.new('white'), Color.new(255, 255, 128), GradientFillDirection::Y))

# Create new BarLayers and add them to the chart.
chart.addLayer(BarLayer.new(Vector.new(dataSet1Data), Color.new(dataSet1ColorName), dataSet1Name ))
chart.addLayer(BarLayer.new(Vector.new(dataSet2Data), Color.new(dataSet2ColorName), dataSet2Name ))
chart.addLayer(BarLayer.new(Vector.new(dataSet3Data), Color.new(dataSet3ColorName), dataSet3Name  ))
chart.addLayer(BarLayer.new(Vector.new(dataSet4Data), Color.new(dataSet4ColorName), dataSet4Name ))
chart.addLayer(BarLayer.new(Vector.new(dataSet5Data), Color.new(dataSet5ColorName), dataSet5Name ))

# Create legend to right of chart.
legend = Legend.new
legend.setFont(fontName, fontSize * 2.5)
chart.setLegend(legend, LegendLocation::Right)
legend.setBackgroundFill(Color.new('lemonchiffon'))


# Export image to PNG file with a bar gap of 0.5
chart.setBarGap(barGap)
chart.setTitle(graphTitle)
chart.getXAxis().setTickLabels(xTickLabels)

chart.getXAxis().setTickLabelFont(fontName , (fontSize * 2.0 ))
chart.getYAxis().setTickLabelFont(fontName , (fontSize * 2.0 ), 0.0)

chart.getXAxis().setLabelFont(fontName , (fontSize * 2.5 ))
chart.getYAxis().setLabelFont(fontName , (fontSize * 2.5 ), 90.0)

#offscreen.exportImage
offscreen.exportImage(fileName)
