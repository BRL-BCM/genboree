#!/usr/bin/env ruby
require 'uncharted_ruby'
require 'json'
include Uncharted

#need a graphic class with xsize, ysize, scale, barGap, xLegend, yLegend, graphic title, institutionName
xSize = 1000
ySize = 800
scale = 0.63
barGap = 0.5
xLegend = ""
yLegend = 'Number of Genes'
graphTitle = 'BCM Sample Coverage Metrics'
institution = Array.new(["1X", "2X"])
#baseDir="/usr/local/brl/local/apache/htdocs/webapps/java-bin/TCGA-Reporting/"
projectName = ARGV[0]
jsonFileName= ARGV[1]
fileName = ARGV[2]
minNumberGenes = 0
minNumberGenes = ARGV[3].to_i if(!ARGV[3].nil?)
#'coverageSharedGenes.png'
# 'coverageMetrics.png'
#fullJsonPath = "#{baseDir}#{projectName}/data/#{jsonFileName}"
fullJsonPath = ARGV[1]

##### TODO Need a dataSet class with an data(array), colorName(string) name(string)
averageData = JSON.parse(File.read(fullJsonPath))
bcmAverages = averageData["bcm"]
broadAverages = averageData["broad"]
wuAverages = averageData["wu"]



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

# Create compound chart with 4 sub-charts.
compound = CompoundChart.new(2, 2)

# Create offscreen buffer containing chart.
offscreen = OffscreenBuffer.new(xSize, ySize, compound)


graphTitle = 'Sample Coverage Metrics (BCM)'
chartB = XYChart.new(graphTitle, xLegend, yLegend )
av1x = bcmAverages["1x"]
av2x = bcmAverages["2x"]
avGene = bcmAverages["gene"]

slice1x = av1x["0-to-20"].to_i
slice2x = av2x["0-to-20"].to_i
dataSet1Name = '0-20%  Sample Coverage'
dataSet1Data = Array.new([slice1x, slice2x])
dataSet1ColorName = 'green'

slice1x = av1x["20-to-40"].to_i
slice2x = av2x["20-to-40"].to_i
dataSet2Name = '20-40% Sample Coverage'
dataSet2Data = Array.new([slice1x, slice2x])
dataSet2ColorName = 'black'

slice1x = av1x["40-to-60"].to_i
slice2x = av2x["40-to-60"].to_i
dataSet3Name = '40-60%  Sample Coverage'
dataSet3Data = Array.new([slice1x, slice2x])
dataSet3ColorName = 'orange'

slice1x = av1x["60-to-80"].to_i
slice2x = av2x["60-to-80"].to_i
dataSet4Name = '60-80%  Sample Coverage'
dataSet4Data = Array.new([slice1x, slice2x])
dataSet4ColorName = 'brown'

slice1x = av1x["80-to-100"].to_i
slice2x = av2x["80-to-100"].to_i
dataSet5Name = '80-100%  Sample Coverage'
dataSet5Data = Array.new([slice1x, slice2x])
dataSet5ColorName = 'red'

geneTotal = 0
avGene.each_key{|geneNum|
  tempGN = avGene[geneNum].to_i
  geneTotal += tempGN
  }

geneTotal = minNumberGenes if(geneTotal < minNumberGenes)

dataSet6Name = 'Total Genes'
dataSet6Data = Array.new([geneTotal, geneTotal])
dataSet6ColorName = 'blue'

# Set chart area fill.
chartB.setChartAreaFill(GradientFill.new(Color.new('white'), Color.new(255, 255, 128), GradientFillDirection::Y))
# Create new BarLayers and add them to the chart.
chartB.addLayer(BarLayer.new(Vector.new(dataSet1Data), Color.new(dataSet1ColorName), dataSet1Name ))
chartB.addLayer(BarLayer.new(Vector.new(dataSet2Data), Color.new(dataSet2ColorName), dataSet2Name ))
chartB.addLayer(BarLayer.new(Vector.new(dataSet3Data), Color.new(dataSet3ColorName), dataSet3Name  ))
chartB.addLayer(BarLayer.new(Vector.new(dataSet4Data), Color.new(dataSet4ColorName), dataSet4Name ))
chartB.addLayer(BarLayer.new(Vector.new(dataSet5Data), Color.new(dataSet5ColorName), dataSet5Name ))
chartB.addLayer(BarLayer.new(Vector.new(dataSet6Data), Color.new(dataSet6ColorName), dataSet6Name  ))
# Export image to PNG file with a bar gap of 0.5
chartB.setBarGap(barGap)
chartB.setTitle(graphTitle)
chartB.getXAxis().setTickLabels(xTickLabels)
chartB.getXAxis().setTickLabelFont(fontName , (fontSize * 2.0 ))
chartB.getYAxis().setTickLabelFont(fontName , (fontSize * 2.0 ), 0.0)
chartB.getXAxis().setLabelFont(fontName , (fontSize * 2.5 ))
chartB.getYAxis().setLabelFont(fontName , (fontSize * 2.5 ), 90.0)
compound.setChart(0, chartB)

graphTitle = 'Sample Coverage Metrics (Broad)'
chartC = XYChart.new(graphTitle, xLegend, yLegend )
av1x = broadAverages["1x"]
av2x = broadAverages["2x"]
avGene = broadAverages["gene"]

slice1x = av1x["0-to-20"].to_i
slice2x = av2x["0-to-20"].to_i
dataSet1Name = '0-20%  Sample Coverage'
dataSet1Data = Array.new([slice1x, slice2x])
dataSet1ColorName = 'green'

slice1x = av1x["20-to-40"].to_i
slice2x = av2x["20-to-40"].to_i
dataSet2Name = '20-40% Sample Coverage'
dataSet2Data = Array.new([slice1x, slice2x])
dataSet2ColorName = 'black'

slice1x = av1x["40-to-60"].to_i
slice2x = av2x["40-to-60"].to_i
dataSet3Name = '40-60%  Sample Coverage'
dataSet3Data = Array.new([slice1x, slice2x])
dataSet3ColorName = 'orange'

slice1x = av1x["60-to-80"].to_i
slice2x = av2x["60-to-80"].to_i
dataSet4Name = '60-80%  Sample Coverage'
dataSet4Data = Array.new([slice1x, slice2x])
dataSet4ColorName = 'brown'

slice1x = av1x["80-to-100"].to_i
slice2x = av2x["80-to-100"].to_i
dataSet5Name = '80-100%  Sample Coverage'
dataSet5Data = Array.new([slice1x, slice2x])
dataSet5ColorName = 'red'

geneTotal = 0
avGene.each_key{|geneNum|
  tempGN = avGene[geneNum].to_i
  geneTotal += tempGN
  }
geneTotal = minNumberGenes if(geneTotal < minNumberGenes)

dataSet6Name = 'Total Genes'
dataSet6Data = Array.new([geneTotal, geneTotal])
dataSet6ColorName = 'blue'



# Set chart area fill.
chartC.setChartAreaFill(GradientFill.new(Color.new('white'), Color.new(255, 255, 128), GradientFillDirection::Y))
# Create new BarLayers and add them to the chart.
chartC.addLayer(BarLayer.new(Vector.new(dataSet1Data), Color.new(dataSet1ColorName), dataSet1Name ))
chartC.addLayer(BarLayer.new(Vector.new(dataSet2Data), Color.new(dataSet2ColorName), dataSet2Name ))
chartC.addLayer(BarLayer.new(Vector.new(dataSet3Data), Color.new(dataSet3ColorName), dataSet3Name  ))
chartC.addLayer(BarLayer.new(Vector.new(dataSet4Data), Color.new(dataSet4ColorName), dataSet4Name ))
chartC.addLayer(BarLayer.new(Vector.new(dataSet5Data), Color.new(dataSet5ColorName), dataSet5Name ))
chartC.addLayer(BarLayer.new(Vector.new(dataSet6Data), Color.new(dataSet6ColorName), dataSet6Name  ))
# Export image to PNG file with a bar gap of 0.5
chartC.setBarGap(barGap)
chartC.setTitle(graphTitle)
chartC.getXAxis().setTickLabels(xTickLabels)
chartC.getXAxis().setTickLabelFont(fontName , (fontSize * 2.0 ))
chartC.getYAxis().setTickLabelFont(fontName , (fontSize * 2.0 ), 0.0)
chartC.getXAxis().setLabelFont(fontName , (fontSize * 2.5 ))
chartC.getYAxis().setLabelFont(fontName , (fontSize * 2.5 ), 90.0)
compound.setChart(1, chartC)



graphTitle = 'Sample Coverage Metrics (WU)'
chartW = XYChart.new(graphTitle, xLegend, yLegend )
av1x = wuAverages["1x"]
av2x = wuAverages["2x"]
avGene = wuAverages["gene"]

slice1x = av1x["0-to-20"].to_i
slice2x = av2x["0-to-20"].to_i
dataSet1Name = '0-20%  Sample Coverage'
dataSet1Data = Array.new([slice1x, slice2x])
dataSet1ColorName = 'green'

slice1x = av1x["20-to-40"].to_i
slice2x = av2x["20-to-40"].to_i
dataSet2Name = '20-40% Sample Coverage'
dataSet2Data = Array.new([slice1x, slice2x])
dataSet2ColorName = 'black'

slice1x = av1x["40-to-60"].to_i
slice2x = av2x["40-to-60"].to_i
dataSet3Name = '40-60%  Sample Coverage'
dataSet3Data = Array.new([slice1x, slice2x])
dataSet3ColorName = 'orange'

slice1x = av1x["60-to-80"].to_i
slice2x = av2x["60-to-80"].to_i
dataSet4Name = '60-80%  Sample Coverage'
dataSet4Data = Array.new([slice1x, slice2x])
dataSet4ColorName = 'brown'

slice1x = av1x["80-to-100"].to_i
slice2x = av2x["80-to-100"].to_i
dataSet5Name = '80-100%  Sample Coverage'
dataSet5Data = Array.new([slice1x, slice2x])
dataSet5ColorName = 'red'

geneTotal = 0
avGene.each_key{|geneNum|
  tempGN = avGene[geneNum].to_i
  geneTotal += tempGN
  }
geneTotal = minNumberGenes if(geneTotal < minNumberGenes)

dataSet6Name = 'Total Genes'
dataSet6Data = Array.new([geneTotal, geneTotal])
dataSet6ColorName = 'blue'

# Set chart area fill.
chartW.setChartAreaFill(GradientFill.new(Color.new('white'), Color.new(255, 255, 128), GradientFillDirection::Y))
# Create new BarLayers and add them to the chart.
chartW.addLayer(BarLayer.new(Vector.new(dataSet1Data), Color.new(dataSet1ColorName), dataSet1Name ))
chartW.addLayer(BarLayer.new(Vector.new(dataSet2Data), Color.new(dataSet2ColorName), dataSet2Name ))
chartW.addLayer(BarLayer.new(Vector.new(dataSet3Data), Color.new(dataSet3ColorName), dataSet3Name  ))
chartW.addLayer(BarLayer.new(Vector.new(dataSet4Data), Color.new(dataSet4ColorName), dataSet4Name ))
chartW.addLayer(BarLayer.new(Vector.new(dataSet5Data), Color.new(dataSet5ColorName), dataSet5Name ))
chartW.addLayer(BarLayer.new(Vector.new(dataSet6Data), Color.new(dataSet6ColorName), dataSet6Name  ))
# Export image to PNG file with a bar gap of 0.5
chartW.setBarGap(barGap)
chartW.setTitle(graphTitle)
chartW.getXAxis().setTickLabels(xTickLabels)
chartW.getXAxis().setTickLabelFont(fontName , (fontSize * 2.0 ))
chartW.getYAxis().setTickLabelFont(fontName , (fontSize * 2.0 ), 0.0)
chartW.getXAxis().setLabelFont(fontName , (fontSize * 2.5 ))
chartW.getYAxis().setLabelFont(fontName , (fontSize * 2.5 ), 90.0)
compound.setChart(2, chartW)

# Create legend to right of chart.
legend = Legend.new(chartB)
legend.setFont(fontName, fontSize * 1.5)
#chart.setLegend(legend, LegendLocation::Right)
#legend.setBackgroundFill(Color.new('lemonchiffon'))
compound.setChart(3, legend)

#offscreen.exportImage
offscreen.exportImage(fileName)
