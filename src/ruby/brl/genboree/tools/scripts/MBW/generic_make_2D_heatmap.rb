#!/usr/bin/env ruby
require 'fileutils'
require "brl/util/textFileUtil"
require "brl/util/util"
require 'roo'

DEBUG = 0

def processArguments()
    # We want to add all the prop_keys as potential command line options
      optsArray = [ ['--inputmatrix','-i', GetoptLong::REQUIRED_ARGUMENT],
                    ['--outputFolder','-o', GetoptLong::REQUIRED_ARGUMENT],
                    ['--dendrogram','-d', GetoptLong::REQUIRED_ARGUMENT],
                    ['--distFun','-f', GetoptLong::REQUIRED_ARGUMENT],
                    ['--hclustFun','-h', GetoptLong::REQUIRED_ARGUMENT],
                    ['--key','-k', GetoptLong::REQUIRED_ARGUMENT],
                    ['--keySize' ,'-s', GetoptLong::REQUIRED_ARGUMENT],
                    ['--trace' ,'-t', GetoptLong::REQUIRED_ARGUMENT],
                    ['--density' ,'-y', GetoptLong::REQUIRED_ARGUMENT],
                    ['--color' ,'-c', GetoptLong::REQUIRED_ARGUMENT],
                    ['--height' ,'-H', GetoptLong::REQUIRED_ARGUMENT],
                    ['--width' ,'-W', GetoptLong::REQUIRED_ARGUMENT],
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
                    --inputmatrix               |  -i => input_matrix_file.txt
                    --outputFolder              |  -o => output_folder/
                    --dendrogram                |  -d => both, none, row, or column
                    --distfun                   |  -f => dist or function(...) 
                    --hclustFun                 |  -h => hclust or function(...)
                    --key                       |  -k => TRUE or FALSE
                    --keySize                   |  -s => 0.75
                    --trace                     |  -t => none, row, both, or column
                    --density                   |  -y => none, histogram, density
                    --color                     |  -c => Spectral, BrBG, PiYG, PRGn, PuOr, RdBu, RdGy, RdYlBu, RdYlGn, heat.colors, or (custom) white,red,blue,darkolivegreen2,#FFD39B,#98F5FF
                    --height                    |  -H => 8
                    --width                     |  -W => 10


usage:
   generic_make_2D_heatmap.rb -i matrix.txt -o outputFolder/ -d both -f dist -h hclust -k TRUE -s 0.75 -t none -y none -c Spectral -H 8 -W 10

";
   exit;
end

class Heat
  DEBUG=FALSE

  attr_reader :opthash, :outputDirectory

  #return full file path
  def fep(file)
    return File.expand_path(file)
  end

  #initialize data elements
  def initialize(settinghash)
    @opthash=settinghash
    @matrixFile = File.expand_path(opthash["--inputmatrix"])
    @outputDirectory = File.expand_path(opthash["--outputFolder"])

    #create output directory
    FileUtils.mkdir_p @outputDirectory

    #store color
    @color = Hash.new(0)

    @rowCount = 0
    @colCount = 0

    @longestRowString = ""
    @longestColString = ""

    @color = ""

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
    color = @opthash["--color"]
    outColor = ""

    #see if we have color brewer argument
    if color == "Spectral" || color == "BrBG" || color == "PiYG" || color == "PRGn" || color == "PuOr" || color == "RdBu" || color == "RdGy" || color == "RdYlBu" || color == "RdYlGn"
      outColor = ",\n\tcol=brewer.pal(10,\"#{color}\")"
    elsif color == "heat.colors"
      outColor = ",\n\tcol=\"heat.colors\""
    #otherwise we might have custom list
    else
      #see if we have comma separated list for custom entries
      if color =~ /\,/
        spl = color.split(",")
        outColor = ",\n\tcol=c("
        spl.each_with_index{ |val,count|
          outColor += "," if count > 0
          outColor += "\"#{val}\""
        }
        outColor += ")" 
      else
        #use spectral as default
        outColor = ",\n\tcol=brewer.pal(10,\"Spectral\")"
      end
    end

    @color = outColor
  end

  def makeHeatMap()
    #first we need to determine the margins so we can best properly fit
    #  the text on the screen

    @rowCount -= 1
    @colCount -= 1 
    
    #puts @longestRowString
    #puts @longestColString

    #puts @rowCount
    #puts @colCount

    cexRow = 0.2 + (1/(Math.log10(@rowCount.to_i)))
    cexCol = 0.2 + (1/(Math.log10(@colCount.to_i)))

    #puts "#{@longestColString.to_i} * #{cexCol.to_f}) + 1) / 2)"
    @rightMargin = (((@longestColString.to_i * cexRow.to_f) + 2) / 2).round

    @bottomMargin = (((@longestRowString.to_i * cexCol.to_f) + 2) / 2).round

    rFile = @outputDirectory + "/" + File.basename(@matrixFile) + ".heat.R"
    w = File.open(rFile, "w")

    pdfFile = @outputDirectory + "/" + File.basename(@matrixFile) + ".heatmap.PDF"
    pngFile = @outputDirectory + "/" + File.basename(@matrixFile) + ".heatmap.PNG"

    xAxis = ""
    yAxis = ""

    w.puts "
	setwd(\"#{@outputDirectory}\")
	library(RColorBrewer)
	library(gplots)
	x <- read.table(\"#{@matrixFile}\", row.names=1, header=TRUE, sep=\"\\t\", na.strings= \"NA\")
	mat=data.matrix(x)
	pdf(\"#{pdfFile}\", height=#{@opthash["--height"]}, width=#{@opthash["--width"]})
	heatmap.2(mat,
	Rowv=TRUE,
	Colv=TRUE,
	dendrogram=c(\"#{@opthash["--dendrogram"]}\"),
	distfun = #{@opthash["--distFun"]},
	hclustfun = #{@opthash["--hclustFun"]},
	xlab = \"#{xAxis}\",
	ylab = \"#{yAxis}\",
	key=#{@opthash["--key"]},
	keysize=#{@opthash["--keySize"]},
	trace=\"#{@opthash["--trace"]}\",
	margins=c(#{@bottomMargin}, #{@rightMargin}),
	density.info=c(\"#{@opthash["--density"]}\")#{@color}
	)
	dev.off()
	"
    w.close()

    #run R command
    `R --vanilla < #{rFile}`
    #convert the PDF to PNG
    `convert -density 450 #{pdfFile} #{pngFile}`
    #delete the PDF file
    `rm -rf #{pdfFile}`

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
    #set color for heatmap
    setColor()
    #prepare matrix into proper format coming from xls, xlsx, csv, or tsv
    prepMatrix()
    #produce heat map
    makeHeatMap()
  end

end

#check for proper usage and exit if necessary
settinghash=processArguments()

#initialize input data
heat = Heat.new(settinghash)

#perform alpha diversity pipeline via work function
heat.work()
exit 0
