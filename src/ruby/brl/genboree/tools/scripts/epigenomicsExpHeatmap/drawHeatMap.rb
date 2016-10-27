#!/usr/bin/env ruby
require 'fileutils'
require "brl/util/textFileUtil"
require "brl/util/util"
require 'roo'

# @todo SHOULD BE PROPER ScriptDriver SCRIPT, NOT HIGGILY PIGGILY

DEBUG = 0

PALETTES =
{
  :Spectral => { :palSize => 11, :rev => true },
  :RdGy     => { :palSize => 11, :rev => true },
  :RdBu     => { :palSize => 11, :rev => true },
  :PuOr     => { :palSize => 11, :rev => false },
  :PRGn     => { :palSize => 11, :rev => false },
  :PiYG     => { :palSize => 11, :rev => true },
  :Blues    => { :palSize =>  9, :rev => false },
  :Reds     => { :palSize =>  9, :rev => false },
  :Greens   => { :palSize =>  9, :rev => false },
  :Oranges  => { :palSize =>  9, :rev => false },
  :Greys    => { :palSize =>  9, :rev => false },
  :YlOrRd   => { :palSize =>  9, :rev => false },
  :YlOrRd   => { :palSize =>  9, :rev => false },
  :YlOrRd   => { :palSize =>  9, :rev => false }
}

def processArguments()
  # We want to add all the prop_keys as potential command line options
    optsArray = [
                  [ '--inputmatrix',  '-i', GetoptLong::REQUIRED_ARGUMENT ],
                  [ '--outputFolder', '-o', GetoptLong::REQUIRED_ARGUMENT ],
                  [ '--dendrogram',   '-d', GetoptLong::OPTIONAL_ARGUMENT ],
                  [ '--distFun',      '-f', GetoptLong::OPTIONAL_ARGUMENT ],
                  [ '--hclustFun',    '-h', GetoptLong::OPTIONAL_ARGUMENT ],
                  [ '--key',          '-k', GetoptLong::OPTIONAL_ARGUMENT ],
                  [ '--density',      '-y', GetoptLong::OPTIONAL_ARGUMENT ],
                  [ '--color',        '-c', GetoptLong::OPTIONAL_ARGUMENT ],
                  [ '--forceSquare',  '-S', GetoptLong::NO_ARGUMENT ]
                ]
    progOpts = GetoptLong.new(*optsArray)
    usage("USAGE ERROR: some required arguments are missing") unless(progOpts.getMissingOptions().empty?)
    optsHash = progOpts.to_hash
    return optsHash
end

def usage(msg='')
    unless(msg.empty?)
      puts "\n#{msg}\n"
    end
    puts "

  PROGRAM DESCRIPTION:
   Microbiome workbench generic 2D heatmap pipeline

  COMMAND LINE ARGUMENTS:
    --inputmatrix   |  -i => input_matrix_file.txt
    --outputFolder  |  -o => output_folder/
    --dendrogram    |  -d => Which dendrograms to draw? Default: both [both, none, row, column]
    --distFun       |  -f => What distance metric to use when clustering? Default: euclidean [binary, canberra, euclidean, manhattan, maximum, minkowski, cor, abscor, sqcor, passThrough]
    --hclustFun     |  -h => What clustering method to user? Default: complete [complete, ward, single, average, mcquitty, median, centroid]
    --key           |  -k => Draw color legend? Default: TRUE [TRUE, FALSE]
    --density       |  -y => How to draw the score distribution on the legend? Default: density [none, histogram, density]
    --forceSquare   |  -S => Force the heatmap image dimensions to be square, distorting the cells if necessary. Default: off
    --color         |  -c => What color palette to use? Default: Spectral [#{PALETTES.keys.join(", ")}]

Usage:
  drawHeatMap.rb -i matrix.txt -o outputFolder/ -d both -f dist -h hclust -k TRUE -y density -c Spectral

";
   exit(145)
end

class Heat
  DEBUG = FALSE

  attr_reader :opthash, :outputDirectory

  #return full file path
  def fep(file)
    return File.expand_path(file)
  end

  #initialize data elements
  def initialize(settinghash)
    # Extract settings info
    @opthash = settinghash
    @matrixFile = File.expand_path(@opthash["--inputmatrix"])
    @outputDirectory = File.expand_path(@opthash["--outputFolder"])
    @dendrogram = @opthash["--dendrogram"].to_s.strip
    @dendrogram = "both" unless(@dendrogram =~ /\S/)
    @distFun    = @opthash["--distFun"].to_s.strip
    @distFun    = "euclidean" unless(@distFun =~ /\S/)
    @hclustFun  = @opthash["--hclustFun"].to_s.strip
    @hclustFun  = "complete" unless(@hclustFun =~ /\S/)
    @key        = @opthash["--key"].to_s.strip
    @key        = "TRUE" #unless(@key =~ /^(?:TRUE|FALSE)$/): setting this to false crashes the tool.
    @density    = @opthash["--density"].to_s.strip
    @density    = "density" unless(@density =~ /\S/)
    @forceSquare = @opthash.key?("--forceSquare")
    @color      = nil  # handled in setColor() to something appropriate or default

    # Bad fixed-width sizing approach:
    @staticHeight = 10
    @staticWidth  = 8

    # create output directory
    FileUtils.mkdir_p(@outputDirectory)

    @rowCount = 0
    @colCount = 0

    @longestRowString = ""
    @longestColString = ""
  end

  def getLongestString(arr)
    maxlen = 0
    arr.each{ |val|
      len = val.length
      maxlen = len if len > maxlen
    }
    return maxlen
  end

  def setColor()
    color = (@opthash["--color"] or :Spectral)
    # ensure it's a supported one; if not, force Spectral (the default)
    color = color.to_sym
    color = :Spectral unless(PALETTES.key?(color))
    # build color brewer palette call
    cConf = PALETTES[color]
    if(cConf[:rev])
      outColor = "col=rev(brewer.pal(#{cConf[:palSize]}, \"#{color}\"))"
    else
      outColor = "col=brewer.pal(#{cConf[:palSize]}, \"#{color}\")"
    end

    return @color = outColor
  end

  def makeHeatMap()
    rFile = @outputDirectory + "/" + File.basename(@matrixFile) + ".heat.R"
    w = File.open(rFile, "w")

    svgFile = @outputDirectory + "/" + File.basename(@matrixFile) + ".heatmap.svg"
    pdfFile = @outputDirectory + "/" + File.basename(@matrixFile) + ".heatmap.pdf"
    pngFile = @outputDirectory + "/" + File.basename(@matrixFile) + ".heatmap.png"
    # For use by the corrplot call
    corrSvgFile = @outputDirectory + "/" + File.basename(@matrixFile) + ".corrplot.svg"
    corrPdfFile = @outputDirectory + "/" + File.basename(@matrixFile) + ".corrplot.pdf"
    corrPNGFile = @outputDirectory + "/" + File.basename(@matrixFile) + ".corrplot.png"

    distString = nil

    # R's cor always works on columns of matrix. So "rows" needs a transposed matrix and vice-versa
    if(@opthash["--distFun"] == "cor")
      distString = "distmat <- as.dist(1-cor(t(mat)));\ntdistmat<-as.dist(1-cor(mat))"
    elsif(@opthash["--distFun"] == "abscor")
      distString = "distmat <- as.dist(1-abs(cor(t(mat))));\ntdistmat<-as.dist(1-abs(cor(mat)))"
    elsif(@opthash["--distFun"] == "sqcor")
      distString = "distmat <- as.dist(1 - (cor(t(mat))*cor(t(mat))));\ntdistmat <- as.dist(1 - (cor(mat)*cor(mat)))"
    elsif(@opthash["--distFun"] == "passThrough")
      distString = "distmat <- as.dist(1-mat);\ntdistmat <- as.dist(1-t(mat))"
    else
      distString = "distmat <- dist(mat,method=\"#{@distFun}\");\ntdistmat <- dist(t(mat),method=\"#{@distFun}\")"
    end

    xAxis = ""
    yAxis = ""
    w.puts "
  # Load packages
  setwd(\"#{@outputDirectory}\")
  library(RColorBrewer)
  library(gplots)
  library(hybridHclust)
  library('ctc')
  library('corrplot')
  library('Cairo')

  # Read data matrix (tab delim file with header row) and get dims
  x <- read.table(\"#{@matrixFile}\", row.names=1, header=TRUE, sep=\"\\t\", na.strings= \"NA\",check.names=FALSE)
  rowCount <- dim(x)[1]
  colCount <- dim(x)[2]

  # Longest col & row name lengths, with adjustment
  lcl <- max(nchar(names(x)))
  lrl <- max(nchar(row.names(x)))
  lcl <- (lcl + log10(lcl))
  lrl <- (lrl + log10(lcl))

  # Axis magnification (cex.axis; values used also to affect: 2x2 grid proportions, margins/gutters for axis labels)
  # . Note: it's not clear that the margins for the labels should depend on axis heights. Maybe just lcl & lrl. Kept for now.
  cexRow <- (if(rowCount > colCount) 0.30 else 0.25) + 1/log10(rowCount)
  cexCol <- (if(rowCount > colCount) 0.25 else 0.30) + 1/log10(colCount)

  # Margins/gutters size for axis labels, with adjustment
  # . Fixed: right margin is used for the ROW labels, bottom margin is used for COL labels
  rightMargin  <- ((lrl*cexRow)/2) + log10(lrl)
  bottomMargin <- ((lcl*cexCol)/2) + log10(lcl)

  # HEATMAP image dimensions. Attempt to scale dynamically based on |X| and |Y|
  # . TODO: Ruby insert R code to force square dimensions on the heatmap? (i.e. imageWidth <- max(imageWidth, imageHeight) ; imageHeight <- max(imageWidth, imageHeight))
  # .       Easy enough, but would this affect our col1Wid and row1Hei proportionality number for the layout.
  # .       If so, possibly returning to default layout ratios (1.5, 4), (1.5, 4) when forcing square image may be indicated.
  # .       Regardless, calcs here are aimed at achieving non-distorted cells; well, not grossly distorted.
  nCexCol <- (if(rowCount >= colCount) (cexCol*1.5) else cexCol)
  nCexRow <- (if(rowCount >= colCount) cexRow else (cexRow*1.5))
  imageWidth <- round((colCount*nCexCol+rightMargin)/4)
  imageHeight <- round((rowCount*nCexRow+bottomMargin)/4)
  #{"imageWidth <- max(imageWidth, imageHeight)" if(@forceSquare)}
  #{"imageHeight <- max(imageWidth, imageHeight)" if(@forceSquare)}

  # heatmap.2 uses a 2x2 grid to layout the heatmap. While 3x2 and 2x3 is possible, unfortunately it has a bug
  # which prevents 3x3 which would be nice for isolating the legend (as it is dendrograms will influence legend size)
  # . Note: the default layout is 4,3,2,1 ; legend, colDend, rowDend, heatmap (with labels)
  # . Note: the default proportions of the col widths is (1.5, 4) while the default proportions of the row widths is (1.5, 4)
  # . Thus: obviously when rows >> cols, the row 1 height of 1.5 is INAPPROPRIATE for dendro (and lengend! see layout) height for so few cols
  # . Thus: obviously when cols >> rows, the col 1 width of 1.5 is INAPPROPRIATE for dendro (and lengend! see layout) width for so few rows
  # . Thus: this is an issue for non-forced-square images, um, duh. Thus probably will put these ratios as 1.5,4 and 1.5,4 for square option
  #
  # --------------------------------------------
  # ATTEMPT 2 - ah, much more reasonable
  # - ratio here is based on the calculated image dims
  # - we have a baseline image width and height, and we know the baseline col1Wid and row1Hei
  #   to use if the image is that size
  # - as the calculated image dimensions deviate away from the baseline, adjust the ratio
  #   to keep same absolute size of col1Wid and row1Hei (more or less)
  # - that organizing principle prevents the col1Wid and row1Hei (i.e. dendrogram heights)
  #   from getting inflated a whole bunch when we have a massive |rows| and/or |cols|
  #   . as a corollary, the legend doesn't get out of wack either; its dimensions are tied to the 2 dendrogram heights
  # - i.e. we downscale col1Wid and row1Hei as |cols| and |rows| grow, respectively
  # --------------------------------------------
  # Baseline image size & ratio assumptions
  baselineImageWid <- 7
  baselineImageHei <- 7
  baselineWidRatio <- 1.8
  baselineHeiRatio <- 1.5
  # Compute scale factor for calculating col1Wid and row1Hei
  # . Adapted from the default layout ratios & image size: e.g. (1.5 / 4 = (X / 7) / (1.5 * log(7) )) where 1.5*log(7) accelerates the scale-down the farther the calculated dimension get from 7
  scaleFactorWid   <- (((baselineWidRatio * baselineImageWid) / 4) * (1.5 * log10(baselineImageWid)))
  scaleFactorHei   <- (((baselineHeiRatio * baselineImageHei) / 4) * (1.5 * log10(baselineImageHei)))
  # Compute our col1Wid & row1Hei by using the scaleFactors & our calculated image dimensions
  # . Same equation as above, except we have 'X', our image dimension is not 7 but has been calculated, and we want to solve for the appropriate number that was '1.5'
  col1Wid <- ((scaleFactorWid * 4) / (imageWidth * (1.5 * log10(imageWidth))))
  row1Hei <- ((scaleFactorHei * 4 ) / (imageHeight * (1.5 * log10(imageHeight))))
  # We need to prevent very small dimensions (6x16, 3x3) from using a huge calculated col1Wid and/or row1Hei, which will look funny
  # . if we've got about the baseline ratios, just use them instead
  col1Wid <- min(col1Wid, baselineWidRatio)
  row1Hei <- min(row1Hei, baselineHeiRatio)

  # Set up data matrix and clustering using the indicated distance metric
  mat <- data.matrix(x)
  #{distString}
  hr<-hclust(distmat,method=\"#{@hclustFun}\")
  rowv<-as.dendrogram(hr)
  hc<-hclust(tdistmat,method=\"#{@hclustFun}\")
  colv<-as.dendrogram(hc)

  # Dump as SVG
  # . Fixed: margin array is bottom (col labels) then right (row labels), not vice versa
  # . Note: we alter the default layout proportions via lwid and lhei
  CairoSVG(\"#{svgFile}\",height=imageHeight,width=imageWidth)
  hmp<-heatmap.2(mat,
  Rowv=rowv,
  Colv=colv,
  dendrogram=c(\"#{@dendrogram}\"),
  xlab = "",
  ylab = "",
  key=#{@key},
  keysize=(col1Wid - 0.05),
  trace=\"none\",
  margins=c(bottomMargin,rightMargin),
  density.info=c(\"#{@density}\"),
  #{@color},
  cexRow=cexRow,
  cexCol=cexCol,
  lwid=c(col1Wid, 4),
  lhei=c(row1Hei, 4)
  )
  dev.off()

  # Dump as pdf
  # . TODO: Probably for PNG generation? Can we just use 'convert a.svg b.png' maybe?
  # . This R heatmap.2 call appears to be the same as for the SVG. Maintaining the redundancy for now.
  pdf(\"#{pdfFile}\",height=imageHeight,width=imageWidth)
  hmp<-heatmap.2(mat,
  Rowv=rowv,
  Colv=colv,
  dendrogram=c(\"#{@dendrogram}\"),
  xlab = "",
  ylab = "",
  key=#{@key},
  keysize=(col1Wid - 0.05),
  trace=\"none\",
  margins=c(bottomMargin,rightMargin),
  density.info=c(\"#{@density}\"),
  #{@color},
  cexRow=cexRow,
  cexCol=cexCol,
  lwid=c(col1Wid, 4),
  lhei=c(row1Hei, 4)
  )
  dev.off()

  # Dump Newick files with tree info.
  write(hc2Newick(hr),file=\"rows.newick.txt\")
  write(hc2Newick(hc),file=\"columns.newick.txt\")

  # Create CorrPlot.
  #. TODO: not dynamically scaled! Fixed size even when only few rows and/or cols, etc. Possibly bad :(
  charWidth   <- 0.72
  charHeight  <- 0.72
  # Length of longest row/col labels
  lclLength   <- max(charWidth, (charWidth * lcl))
  lrlLength   <- max(charWidth, (charWidth * lrl))
  # dim = {image dim} + {label size} + {key width}
  corrPlotWidth   <- max(charWidth, (((charWidth * colCount) / 2) + lrlLength))
  corrPlotHeight  <- max(charWidth, (((charWidth * rowCount) / 2) + lclLength))
  # Write SVG
  CairoSVG(\"#{corrSvgFile}\", height=corrPlotHeight, width=corrPlotWidth)
  corrplot(mat[rev(hmp$rowInd), hmp$colInd], tl.cex=2, cl.cex=2, tl.col=\"#000000\")
  dev.off()

  # Write PDF
  pdf(\"#{corrPdfFile}\", height=corrPlotHeight, width=corrPlotWidth)
  corrplot(mat[rev(hmp$rowInd), hmp$colInd], tl.cex=2, cl.cex=2, tl.col=\"#000000\")
  dev.off()
  "
    w.close()

    # run R command
    `R --vanilla < #{rFile} > R.out 2> R.err`

    # convert the PDF to PNG
    `convert -density 450 #{pdfFile} #{pngFile}`
    # - convert to cropped version to make consistent margins etc.
    `convert #{pngFile} -trim -bordercolor white -border 15x15 -verbose #{pngFile}`
    #`cp #{svgFile} #{svgFile}.html`
    # delete the PDF file
    # `rm -rf #{pdfFile}`
    # - sample PDF at high res
    `convert -density 450 #{corrPdfFile} #{corrPNGFile}`
    # - convert to smaller, but legible png at low res.
    `convert #{corrPNGFile} -resize 10% #{corrPNGFile} `
    # - convert to cropped version to deal with any oversizing due to above corrplot sizing calcs in R.
    `convert #{corrPNGFile} -trim -bordercolor white -border 10x10 -verbose #{corrPNGFile}`
    #`rm -rf #{corrPdfFile}`
  end

  def prepMatrix()
    #if we have an xls or xlsx file convert it to csv
    if @matrixFile =~ /\.xlsx$/ || @matrixFile =~ /\.xls$/
      @matrixFile = xlsORxlsxTOcsv(@matrixFile)
    end
    #if we have a csv file (which may or may not have been generated from a
    #  xls(x) doc
    if @matrixFile =~ /\.csv$/
      @matrixFile = csvToTSV(@matrixFile)
    end
    #otherwise assume we have a tab-delmited file
    #check to see if we have entry in 0,0 - if not we need to add one
    # this is all assuming that we have a correct matrix with a constant size
    tmpFile = @outputDirectory + "/" + File.basename(@matrixFile) + ".fixed"
    w = File.open(tmpFile, "w")

    reader = File.open(@matrixFile, "r")

    header = reader.gets.strip
    row2 = reader.gets.strip

    @rowCount = 2
    headerSpl = header.split("\t")

    @row1size = headerSpl.length
    @colCount = row2.split("\t").length

    #@longestRowString = getLongestString(headerSpl)

    rowNames = []

    #we are likely experiencing a blank 0,0 position.  attempt to fix this
    # for the user
    if @row1size == (@colCount -1)
      $stderr.puts "It looks like you may have an incorrect number of rows or potentially a blank first row, first column [0,0].  Attempting to fix..."
      w.print "___\t"
    #otherwise if we have normal condition
    elsif @row1size == @colCount

    #otherwise we have some weird formatted data and need to exit
    else
      $stderr.puts "ERROR: First two rows do not have compatible sizes...\tExiting."
      exit 1
    end

    headerFixedVal = header
    #delete default extension if we have GMT formatted files
    headerFixedVal = header.gsub(/\.fa\.ignore\.\.ana/,"")

    @longestRowString = getLongestString(headerFixedVal.split("\t"))
    w.puts headerFixedVal
    w.puts row2
    reader.each{ |line|
      spl = line.split("\t")
      rowNames.push(spl[0])
      w.puts line
      @rowCount += 1
    }
    @matrixFile = tmpFile

    reader.close()
    w.close()

    @longestColString = getLongestString(rowNames)

  end

  def csvToTSV(file)
    tmpFile =  @outputDirectory + "/" + File.basename(file) + ".tsv"
    r = File.open(file, "r")
    w = File.open(tmpFile, "w")
    r.each_with_index{ |line, count|
      line.strip!
      outLine = line.split(",").join("\t").gsub(/\"/,"")
      w.puts outLine
    }
    r.close()
    w.close()
    return tmpFile

  end

  def xlsORxlsxTOcsv(file)
    tmpFile = file
    if file =~ /\.xlsx$/
      tmpFile = @outputDirectory + "/" + File.basename(file) + ".csv"
      oo = Excelx.new(file)
      oo.default_sheet = oo.sheets.first
      oo.to_csv(tmpFile)
    elsif file =~ /\.xls$/
      tmpFile = @outputDirectory + "/" + File.basename(file) + ".csv"
      oo = Excel.new(file)
      oo.default_sheet = oo.sheets.first
      oo.to_csv(tmpFile)
    end
    return tmpFile
  end


  def work()
    # set color for heatmap
    setColor()
    # prepare matrix into proper format coming from xls, xlsx, csv, or tsv
    prepMatrix()
    # produce heat map
    makeHeatMap()
  end

end

# ------------------------------------------------------------------
# MAIN
# ------------------------------------------------------------------

# check for proper usage and exit if necessary
settinghash = processArguments()

# initialize input data
heat = Heat.new(settinghash)

# perform alpha diversity pipeline via work function
heat.work()
exit 0
