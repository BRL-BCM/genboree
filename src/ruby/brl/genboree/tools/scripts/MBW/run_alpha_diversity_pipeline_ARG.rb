#!/usr/bin/env ruby
require 'fileutils'
#require "/home/junm/microbiomeWorkbench/brlheadmicrobiome/brlMatrix.rb"
require "brl/util/textFileUtil"
require "brl/util/util"
require 'brl/microbiome/workbench/brlMatrix.rb'


def processArguments()
    # We want to add all the prop_keys as potential command line options
      optsArray = [ ['--Qiimefolder','-f', GetoptLong::REQUIRED_ARGUMENT],
                    ['--outputFolder','-o', GetoptLong::REQUIRED_ARGUMENT],
                    ['--colors','-c', GetoptLong::REQUIRED_ARGUMENT],
                    ['--renyiScale','-r', GetoptLong::REQUIRED_ARGUMENT],
                    ['--permutations','-p', GetoptLong::REQUIRED_ARGUMENT],
                    ['--legendBoolChar' ,'-b', GetoptLong::REQUIRED_ARGUMENT],
                    ['--legendPosition' ,'-n', GetoptLong::REQUIRED_ARGUMENT],
                    ['--legendMarkerSizeMod' , '-k', GetoptLong::REQUIRED_ARGUMENT],
                    ['--renyiOffset' ,'-y', GetoptLong::REQUIRED_ARGUMENT],
                    ['--richnessOffset','-l', GetoptLong::REQUIRED_ARGUMENT],
                    ['--richnessOffset2','-g', GetoptLong::REQUIRED_ARGUMENT],
                    ['--height','-h', GetoptLong::REQUIRED_ARGUMENT],
                    ['--width','-w', GetoptLong::REQUIRED_ARGUMENT],
                    ['--rainbow','-i', GetoptLong::REQUIRED_ARGUMENT],
                    ['--meta' ,'-m', GetoptLong::REQUIRED_ARGUMENT],
                    ['--removeSingletons', '-s', GetoptLong::REQUIRED_ARGUMENT],
                    ['--pngDensity' ,'-j', GetoptLong::REQUIRED_ARGUMENT],
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
   Microbiome workbench run QIIME pipeline 
   
  COMMAND LINE ARGUMENTS:
                    --Qiimefolder 		|  -f => QIIMEfolder
                    --outputFolder 		|  -o => outputfolder
                    --colors			|  -c => #8b0000,#000000,#0066FF,#00FF33,#66CDAA,#FF69B4,#FF8C00,#808000,#A9A9A9
                    --renyiScale		|  -r => 0,0.25,0.5,1,2,4,8,Inf
                    --permutations		|  -p => 2
                    --legendBoolChar		|  -b => T
                    --legendPosition		|  -n => right
                    --legendMarkerSizeMod	|  -k => 0
                    --renyiOffset		|  -y => 6
                    --richnessOffset		|  -l => -2
                    --richnessOffset2		|  -g => 40
                    --height			|  -h => 8
                    --width 			|  -w => 8
                    --rainbow			|  -i => F
                    --meta 			|  -m => SampleType
                    --pngDensity 		|  -j => 200
                    --removeSingletons          |  -s => 1

usage:
   run_alpha_diversity_pipeline_ARG.rb -f projecttest1/QIIME_result/ -o projecttest/ -c '#8b0000,#000000,#0066FF,#00FF33,#66CDAA,#FF69B4,#FF8C00,#808000,#A9A9A9' -r '0,0.25,0.5,1,2,4,8,Inf' -p 2 -b T -n right -k 0 -y 6 -l -2 -g 40 -h 8 -w 8 -i F -m SampleType -j 200 -s 1

";
   exit;
end

class AlphaDiversity
  DEBUG=false

   attr_reader :opthash, :outputDirectory
   
   #return full file path
  def fep(file)
    return File.expand_path(file)
  end

  #initialize data elements
  #def initialize(communityFile, environmentFile, metaDataListFile, outputDirectory, defaultSettingsFile, customSettingsFile)
  def initialize(settinghash)
    @opthash=settinghash
    @QIIMEfolder = fep(opthash["--Qiimefolder"]) + "/"
    @communityFile = @QIIMEfolder + "otu_table.txt"
    @environmentFile = @QIIMEfolder + "mapping.txt"
    @outputDirectory = File.expand_path(opthash["--outputFolder"]) + "/alphadiversity/"

    #create output directory
    FileUtils.mkdir_p @outputDirectory 

    #file name to hold intermediary converted community matrix file
    @convertedCommunityFile = String.new(@communityFile)
  end

  #check that input is in proper format and remove any unecessary input
  def fixOriginalInput_CommunityFile()
    #check for traditional signs of an OTU table format and fix if necessary
    cRead = File.open(@communityFile, "r")
    line1 = cRead.gets
    line2 = cRead.gets
    cRead.close()

    stringCheck1 = "\# QIIME\ v1.2.0\ OTU\ table" 
    #stringCheck1 ="\#Full \OTU\ Counts"
    stringCheck2 = "Consensus\ Lineage"

    headerCheckBool = 0
    otuLabelCheckBool = 0

    headerCheckBool = 1 if line1 =~ /#{stringCheck1}/
    otuLabelCheckBool = 1 if line1 =~ /#{stringCheck2}/ || line2 =~ /#{stringCheck2}/

    #if we have an OTU table that needs fixed
    #if headerCheckBool == 1 || otuLabelCheckBool == 1
    newCommFile = File.basename(@communityFile).gsub(/#{File.extname(@communityFile)}/, "-communityFixed.dat")
    newCommFile="#{outputDirectory}/#{newCommFile}"
    w = File.open(newCommFile, "w")   

    #loop through community file and output updated file
    cRead = File.open(@communityFile, "r")
    #ignore first line if we have a header line unique to OTU tables
    cRead.gets if headerCheckBool == 1
      
    #read through OTU table and fix the following issues:
    #  -rename [0,0] to 'sites'
    #  -add an 'X' to beginning of names to avoid data type issues
    #  -replace -s with _s
    #  -remove ' 's
    #  -remove OTU tag if applicable
    
    header = cRead.gets
    headerSplit = header.split("\t")
    headerSize = headerSplit.length
    headerSize -= 1
    #add one position to header length if we do not need to subtract for
    #  OTU label
    headerSize += 1 if otuLabelCheckBool == 0
  
    #print out each header value minus last value if we have OTU labels
    for pos in (0...headerSize)
      if pos == 0
        #substitute in name 'sites' at [0,0]
        w.print "sites"
      else
        #add 'X' in front of all header values
        sampleName = "\tX#{headerSplit[pos].strip}"
        sampleName.gsub!(/\-/, "")
        sampleName.gsub!(/\ /, "")
        w.print sampleName
      end
    end 
    w.puts
 
    #loop through remaining lines after header line
    cRead.each{ |line|
      headerSplit = line.split("\t")
      for pos in (0...headerSize)
        if pos == 0
          featureName = "X#{headerSplit[pos]}"
          featureName.gsub!(/\-/, "")
          featureName.gsub!(/\ /, "")
          w.print featureName
        else
          w.print "\t#{headerSplit[pos]}" 
        end 
      end
      w.puts
    }

    cRead.close()
    w.close()

    #save the name of file before transposing so we can use for 
    #  environment file lookup
    @convertedCommunityFile = newCommFile

    #file to contain transposed community file
    transCommFile = newCommFile + ".tr"

    #we then need to transpose this file so it will be compatable for R input
    #create matrix object from brlMatrix.rb
    matrixObject = MatrixWork.new(newCommFile, transCommFile)

    #store input as matrix
    commMatrix = matrixObject.file2matrix(nil)

    #transpose matrix
    transCommMatrix = commMatrix.t

    #export transposed matrix to file
    matrixObject.printMatrix(transCommMatrix, transCommFile)

    #update community file to updated file
    @communityFile = fep(transCommFile)
  end

  def fixOriginalInput_EnvironmentalFile()
    #create name of new env file based on previous env file name 
    newEnvFile = File.basename(@environmentFile).gsub(/#{File.extname(@environmentFile)}/, "-envFixed.dat")
    newEnvFile = "#{outputDirectory}/#{newEnvFile}"
    w = File.open(newEnvFile, "w")

    #loop through community file and output updated file
    eRead = File.open(@environmentFile, "r")
     
    #read through OTU table and fix the following issues:
    #  -rename [0,0] to 'sites'
    #  -add an 'X' to beginning of names to avoid data type issues
    #  -replace -s with _s
    #  -remove ' 's
     
    header = eRead.gets
    headerSplit = header.split("\t")
    headerSize = headerSplit.length
    
    #print out each header value 
    for pos in (0...headerSize)
      if pos == 0
        #substitute in name 'sites' at [0,0]
        w.print "sites"
      else
        sampleName = "#{headerSplit[pos].strip}"
        sampleName.gsub!(/\-/, "")
        sampleName.gsub!(/\ /, "")
        w.print "\t#{sampleName}"
      end
    end
    w.puts

    #hash to store each sample name and line of environmental file
    #  we need to match order of community file or R will break into 
    #  1,000 pieces
    envHsh = Hash.new(0)

    #hash to store community name and line position
    comHsh = Hash.new(0)

    #store number of lines
    envHshCount = 0

    #loop through lines
    eRead.each{ |line|
      headerSplit = line.split("\t")
      resultantLine = ""
      featureName = ""
      for pos in (0...headerSize)
        if pos == 0
          featureName = "X#{headerSplit[pos]}"
          featureName.gsub!(/\-/, "")
          featureName.gsub!(/\ /, "")
        else
          resultantLine += "\t#{headerSplit[pos].strip}"
        end
      end
      envHsh[featureName] = resultantLine
      envHshCount += 1
    }
    eRead.close()

    #store community name and line position
    cRead = File.open(@convertedCommunityFile, "r")
    #split first line into sample names
    cSplit = cRead.gets.split("\t")
    #remove first entry
    cSplit.delete_at(0)

    position = 0
    cSplit.each{ |cName|
      comHsh[position] = cName.strip
      position += 1
    }
    cRead.close()

    #print out each env line with adjusted name
 #   for i in (0...envHshCount)
    for i in (0...position)
      w.puts "#{comHsh[i]}#{envHsh[comHsh[i]]}"
    end

    w.close()
 
    #update community file to updated file
    @environmentFile = fep(newEnvFile)

  end
=begin
  #dynamically set default settings from default settings input file
  def setDefaultSettings()
    opthash=processArguments()
    #@settings will contain the settings from default and custom settings files
    @settings = Object.new

    #read through default settings file
    File.open(@settingsFile, "r").each{ |line|
      puts line
      #split line based on tab delimited setting
      spl = line.split("\t")

      @settings.instance_variable_set(:"@#{spl[0]}", spl[1].strip)
      #puts @settings.instance_variable_get(:"@#{spl[0]}")
    }
  end
=end
  #dynamically set custom settings from custom settings input file
  #  update the default settings where applicable
  #def setCustomSettings()
  #  #read through custom settings file
  #  File.open(@customSettingsFile, "r").each{ |line|
  #    #split line based on tab delimited setting
  #    spl = line.split("\t")
  #
  #    @settings.instance_variable_set(:"@#{spl[0]}", spl[1].strip)
  #    #puts @settings.instance_variable_get(:"@#{spl[0]}")
  #  }
  #end

  #fix settings that need special attention to be permissible in R
  def fixRvars()
    #fix colors
    colors = @settings.instance_variable_get(:@colors) 
    colors=opthash["--colors"]
    colorss=colors.gsub(/\,/, "\"\, \"")
    colorss="\"#{colorss}\""
#    @settings.instance_variable_set(:@colors, "\"#{colors}\"")
    opthash["--colors"]=colorss
  end

  #store meta data into array from file
  # input can be a combination of single lines, tab delimited, 
  # and comma deliminted
  def storeMetaDataArray(metaDataFile)
    @metaArray = []
    File.open(metaDataFile).each{ |line|
      #separate entries by commas
      if line =~ /\,/
        line.split(",").each{ |val|
          @metaArray.push(val.strip.gsub(/\ /,""))
        }
      #separate entries by tabs
      elsif line =~ /\t/
        line.split("\t").each{ |val|
          @metaArray.push(val.strip.gsub(/\ /,""))
        }
      #otherwise simply store entry
      else
        @metaArray.push(line.strip.gsub(/\ /,""))
      end 

      #make sure we have unique list
      @metaArray.uniq!
    }
  end

  #store meta data into array from settings
  # input can be a combination of single lines, tab delimited, 
  # and comma deliminted
  def storeMetaDataArrayFromSettings()
    @metaArray = [] 
    #@settings.instance_variable_get(:@permutations)}
    #File.open(metaDataFile).each{ |line|
    #separate entries by commas 

  #  metaSettings = @settings.instance_variable_get(:@meta)
    metaSettings = opthash["--meta"]
    if metaSettings =~ /\,/ 
      metaSettings.split(",").each{ |val| 
        @metaArray.push(val.strip.gsub(/\ /,""))
      } 
    #separate entries by tabs 
    elsif metaSettings =~ /\t/ 
      metaSettings.split("\t").each{ |val| 
        @metaArray.push(val.strip.gsub(/\ /,""))
      } 
    #otherwise simply store entry
    else 
      @metaArray.push(metaSettings.strip.gsub(/\ /,""))
    end

    #make sure we have unique list 
    @metaArray.uniq! 
    #}
  end

  #get header of samples for proper call in R script
  def getSampleHeader()
    r = File.open(@communityFile, "r")
    @sampleHeader = r.gets.split("\t")[0]
    r.close()
  end

  #execute whatever exists in cmds array (or string) and saves call in 
  # 'fileName'
  def executeRcommands(cmds, fileName)
    rScriptFile = @outputDirectory + "/" + fileName
    w = File.open(rScriptFile, "w")
    #write default R commands for alpha diversity
    w.puts  "setwd(\"#{@outputDirectory}\")"
    w.puts "library(BiodiversityR)"
    w.puts "CommunityDataset <- read.table(\"#{@communityFile}\", row.names=1, header=TRUE, sep=\"\\t\", na.strings= \"NA\")"
    w.puts "EnvironmentalDataset <- read.table(\"#{@environmentFile}\", row.names=1, header=TRUE, sep=\"\\t\", na.strings= \"NA\")"

    cmds.each{ |cmd|
      w.puts cmd
    }
    w.close()

    #invoke R script
    `R --vanilla < #{rScriptFile}`
  end

  def checkInputDataSets()
    outputFileName = "checkData.R"
    errorCheckFileName = outputFileName + ".out"

    cmds = []
    cmds << "setwd(\"#{@outputDirectory}\")"
    cmds << "library(BiodiversityR)"
    cmds << "CommunityDataset <- read.table(\"#{@communityFile}\", row.names=1, header=TRUE, sep=\"\\t\", na.strings= \"NA\")"
    cmds << "EnvironmentalDataset <- read.table(\"#{@environmentFile}\", row.names=1, header=TRUE, sep=\"\\t\", na.strings= \"NA\")"
    cmds << "capture.output(print(check.datasets(CommunityDataset, EnvironmentalDataset)), file=\"#{errorCheckFileName}\")"

    #execute R commands and store output to check for validity of data sets
    executeRcommands(cmds, outputFileName)

    exitBool = 0

    #check R output to see if we have valid data set
    File.open("#{@outputDirectory}/#{errorCheckFileName}", "r").each { |line|
      next if line == "NULL\n"
      #if we have a line other than 'NULL' we have erroneous data
      $stderr.puts line
      exitBool = 1
    }    
  
    #exit if exitBool == 1
    if exitBool == 1
      $stderr.puts "Exiting due to incompatible community and environment data sets"
      exit 2
    end 

  end
 
  def runDiversityIndices()
    diversityVals = %w(richness abundance Shannon Simpson inverseSimpson Logalpha Berger Jevenness Eevenness jack1 jack2 chao boot)
    calculationMethods = %w(all mean sd)

    outputDir = @outputDirectory + "/diversityIndices/"
    #make output dierectory
    FileUtils.mkdir_p outputDir

    #array to store R commands
    cmds = []

    #loop through each meta data value
    @metaArray.each{ |metaVal| 
      #loop through each diversity index
      diversityVals.each{ |diversityVal|
        #loop through each caluculation method
        calculationMethods.each{ |calculationVal|
          outputFile = outputDir + "#{metaVal}-#{diversityVal}-#{calculationVal}.txt"
          cmds << "capture.output(print(diversitycomp(CommunityDataset, y=EnvironmentalDataset, factor1='#{metaVal}', , index='#{diversityVal}' ,method='#{calculationVal}', sortit=FALSE, digits=3)), file=\"#{outputFile}\")"
        }
      }
    }

    #execute R commands and store output for diversity indices
    executeRcommands(cmds, "diversityCmds.R")
  end

  def runSpeciesAccumulationCurvesRichness()
    accumulationMethods = %w(exact random rarefaction coleman collector)
    #accumulationMethods = %w(exact random coleman collector)
    
    outputDir = @outputDirectory + "/richnessPlots/"
    #make output dierectory
    FileUtils.mkdir_p outputDir

    #array to store output pdfs for conversion
    pdfs = []

    #array to store R commands
    cmds = []

    #temporarily hard code two color palette
    #colors = "\"#8b0000\", \"#000000\""  \"\"
    #colors = "\"#8b0000\", \"#000000\", \"#0066FF\", \"#00FF33\", \"#66CDAA\", \"#FF69B4\", \"#FF8C00\", \"#808000\", \"#A9A9A9\""

    
    cmds << "#http://rgm2.lab.nig.ac.jp/RGM2/R_man-2.9.0/library/BiodiversityR/R/accumcomp.R"
    cmds << "`accumcompMOD` <-"
    cmds << "function(x,y=\"\",factor,scale=\"\",method=\"accMethod\",permutations=#{opthash["--permutations"]},conditioned=T,gamma=\"Boot\",plotit=T,labelit=T,legend=T,rainbow=T,xlim=c(1,max),ylim=c(0,rich),type=\"p\",xlab=\"#{@sampleHeader}\",ylab=\"species richness\",...) {"
    cmds << "    groups <- table(y[,factor])"
    cmds << "    min <- min(groups)"
    cmds << "    max <- max(groups)"
    cmds << "    m <- length(groups)"
    cmds << "    levels <- names(groups)"
    cmds << "    result <- array(NA,dim=c(m,max,3))"
    cmds << "    dimnames(result) <- list(level=levels,obs=c(1:max),c(\"Sites\",\"Richness\",\"sd\"))"
    cmds << "    names(dimnames(result)) <- c(factor,\"obs\",\"\")"
    cmds << "    for (i in 1:m) {"
    cmds << "    result1 <- accumresult(x,y,factor,level=levels[i],scale=scale,method=method,permutations=permutations,conditioned=conditioned,gamma=gamma)"
    cmds << "    l <- length(result1$sites)"
    cmds << "    result[i,c(1:l),1] <- result1$sites"
    cmds << "    result[i,c(1:l),2] <- result1$richness"
    cmds << "    if (method!=\"collector\" && method!=\"poisson\" && method!=\"binomial\" && method!=\"negbinomial\") {result[i,c(1:l),3] <- result1$sd}"
    cmds << "    }"
    cmds << "    if (plotit == T) {"
    cmds << "    max <- max(result[,,1],na.rm=T)"
    cmds << "    rich <- max(result[,,2],na.rm=T)"
    cmds << "    for (i in 1:m) {"
    cmds << "        result1 <- accumresult(x,y,factor,level=levels[i],scale=scale,method=method,permutations=permutations,conditioned=conditioned,gamma=gamma)"
    cmds << "        if (plotit == T) {"
    cmds << "        if (i == 1) {addit <- F}"
    cmds << "        if (i > 1) {addit <- T}"
    cmds << "        if (labelit==T) {"
    cmds << "            labels <- levels[i]"
    cmds << "        }else{"
    cmds << "            labels <- \"\""
    cmds << "        }"
    cmds << "        if (rainbow==T) {"
    cmds << "            palette(rainbow(m))"
    cmds << "            accumplotMOD(result1,method=method, factor=factor,addit=addit,xlab=xlab,ylab=ylab,xlim=xlim,ylim=ylim,labels=labels,col=i,pch=i,type=type,...)"
    cmds << "        }else {"
    cmds << "            colors <- c(#{opthash["--colors"]})"
    cmds << "            palette(colors)"
    cmds << "            accumplotMOD(result1,method=method, factor=factor,addit=addit,xlab=xlab,ylab=ylab,xlim=xlim,ylim=ylim,labels=labels,col=i,pch=i,type=type,...)"
    cmds << "        }"
    cmds << "        }"
    cmds << "    }"
    cmds << "    #if (rainbow==T && legend==T) {legend(locator(1),legend=levels,pch=c(1:m)+#{opthash["--legendMarkerSizeMod"]},col=c(1:m))}"
    cmds << "    #if (rainbow==F && legend==T) {legend(locator(1),legend=levels,pch=c(1:m)+#{opthash["--legendMarkerSizeMod"]})}"
    cmds << "    #http://astrostatistics.psu.edu/datasets/R/html/graphics/html/legend.html"
    cmds << "    legend(\"#{opthash["--legendPosition"]}\",legend=levels,pch=c(1:m)+#{opthash["--legendMarkerSizeMod"]},col=c(1:m))    "
    cmds << "    }"
    cmds << "    palette(\"default\")"
    cmds << "    return(result)"
    cmds << "}"
    cmds << ""
    cmds << "`accumplotMOD` <-"
    cmds << "function(xr,addit=F,labels=\"\",method=\"none\", factor=\"none\",col=1,ci=2,pch=1,type=\"p\",cex=1,xlim=c(1,xmax),ylim=c(1,rich),xlab=\"#{@sampleHeader}\",ylab=\"species richness\",...) {"
    cmds << "    x <- xr"
    cmds << "    xmax <- max(x$sites)"
    cmds << "    rich <- max(x$richness)    "
    cmds << "    if(addit==F) {plot(x$sites,x$richness,xlab=xlab,ylab=ylab,bty=\"l\",type=type,col=col,pch=pch,cex=cex,xlim=xlim,ylim=ylim)} "
    cmds << "    if(addit==T) {points(x$sites,x$richness,type=type,col=col,pch=pch,cex=cex)}"
    cmds << "    plot(x,add=T,ci=ci,col=col,...)"
    cmds << "    if(labels!=\"\") {"
    cmds << "    l <- length(x$sites)"
    cmds << "    #text(x$sites[1],x$richness[1],labels=labels,col=col,pos=2,cex=cex)"
    cmds << "    xpos = x$sites[l]"
    cmds << "    ypos = x$richness[l] + 6"
    cmds << "    if (xpos > 200){"
    cmds << "      xpos = xpos - #{opthash["--richnessOffset2"]}"
    cmds << "    }"
    cmds << " #text(xpos,ypos,labels=labels,col=col,pos=4,cex=cex, offset=#{@richnessOffset})"
    cmds << "    }"
    cmds << "    title(paste(factor, method, sep=\" - \"))"
    cmds << "}"

    #loop through each meta data value
    @metaArray.each{ |metaVal|
      #loop through each accumulation method
      accumulationMethods.each{ |accMethod|
        $stderr.puts "#{metaVal}-#{accMethod}"
 
        outputFile = outputDir + "#{metaVal}-#{accMethod}.pdf"
        #store pdf file
        pdfs << outputFile

        cmds << ""
        #cmds << "png(filename= \"#{outputFile}\", width=#{@width}, height=#{@height}, units =\"px\")"
        cmds << "pdf(file= \"#{outputFile}\", height=#{opthash["--height"]}, width=#{opthash["--width"]})"
        cmds << "Accum.1 <- accumcompMOD(CommunityDataset, y=EnvironmentalDataset, "
        cmds << "  factor='#{metaVal}', method='#{accMethod}', conditioned =T, gamma = 'boot', "
        cmds << "  permutations=#{opthash["--permutations"]}, legend=#{opthash["--legendBoolChar"]}, rainbow=#{opthash["--rainbow"]}, ci=2, ci.type='bar', cex=1, "
        cmds << "  xlab='#{@sampleHeader}', scale='')"
        cmds << "dev.off()"
      }
    }

    #execute R commands and store output for species accumulation
    executeRcommands(cmds, "richnessCmds.R")

    #convert each pdf into PNG
    convertPDFtoPNG(pdfs)

  end

  def runRankAbundance()
    rankAbunMethods = %w(abundance proportion logabun accumfreq)

    outputDir = @outputDirectory + "/rankAbundancePlots/"
    #make output dierectory
    FileUtils.mkdir_p outputDir
 
    #array to store output pdfs for conversion
    pdfs = []

    #array to store R commands
    cmds = []

    
    cmds << "#http://rgm2.lab.nig.ac.jp/RGM2/R_man-2.9.0/library/BiodiversityR/R/rankabuncomp.R"
    cmds << "`rankabuncompMOD` <-"
    cmds << "function(x,y=\"\",factor,scale=\"abundance\",scaledx=F,type=\"o\",rainbow=T,legend=T,xlim=c(1,max1), ylim=c(0,max2), ...) {"
    cmds << "    groups <- table(y[,factor])"
    cmds << "    levels <- names(groups)"
    cmds << "    m <- length(groups)"
    cmds << "    max1 <- max(diversitycomp(x,y,factor,index=\"richness\")[,2])"
    cmds << "    if (scaledx==T) {xlim<-c(0,100)}"
    cmds << "    freq <- diversityresult(x,index=\"Berger\")"
    cmds << "    if (scale==\"abundance\") {max2 <- freq * diversityresult(x,index=\"abundance\")}"
    cmds << "    if (scale==\"logabun\") {max2 <- log(freq * diversityresult(x,index=\"abundance\"),base=10)}"
    cmds << "    if (scale==\"proportion\") {max2 <- 100 * max(diversitycomp(x,y,factor,index=\"Berger\")[,2])}"
    cmds << "    if (scale==\"accumfreq\") {max2 <- 100}"
    cmds << "    max2 <- as.numeric(max2)"
    cmds << "    if (rainbow==F) {"
    cmds << "    colors <- c(#{opthash["--colors"]})"
    cmds << "    palette(colors)"
    cmds << "    #rankabunplot(rankabundance(x,y,factor,levels[1]),scale=scale,scaledx=scaledx,type=type,labels=levels[1], xlim=xlim, ylim=ylim, pch=1,specnames=NULL, ...)"
    cmds << "    #for (i in 2:m) {"
    cmds << "    #    rankabunplot(rankabundance(x,y,factor,levels[i]),addit=T,scale=scale,scaledx=scaledx,type=type,labels=levels[i], pch=i,specnames=NULL,...)"
    cmds << "    #}"
    cmds << "    rankabunplotMOD(rankabundance(x,y,factor,levels[1]),scale=scale,scaledx=scaledx,type=type,labels=levels[1],xlim=xlim,ylim=ylim,col=1,pch=1,specnames=NULL,...)"
    cmds << "    for (i in 2:m) {"
    cmds << "        rankabunplotMOD(rankabundance(x,y,factor,levels[i]),addit=T,scale=scale,scaledx=scaledx,type=type,labels=levels[i],col=i,pch=i,specnames=NULL,...)"
    cmds << "    }"
    cmds << "    if (legend==T) {"
    cmds << "      #legend(locator(1),legend=levels,pch=c(1:m))"
    cmds << "      legend(\"#{opthash["--legendPosition"]}\",legend=levels,pch=c(1:m)+#{opthash["--legendMarkerSizeMod"]},col=c(1:m))"
    cmds << "    }"
    cmds << "    palette(\"default\")"
    cmds << "    }else{"
    cmds << "    palette(rainbow(m))"
    cmds << "    rankabunplotMOD(rankabundance(x,y,factor,levels[1]),scale=scale,scaledx=scaledx,type=type,labels=levels[1],xlim=xlim,ylim=ylim,col=1,pch=1,specnames=NULL,...)"
    cmds << "    for (i in 2:m) {"
    cmds << "        rankabunplotMOD(rankabundance(x,y,factor,levels[i]),addit=T,scale=scale,scaledx=scaledx,type=type,labels=levels[i],col=i,pch=i,specnames=NULL,...)"
    cmds << "    }"
    cmds << "    if (legend==T) {"
    cmds << "        #legend(locator(1),legend=levels,pch=c(1:m),col=c(1:m))"
    cmds << "        legend(\"#{opthash["--legendPosition"]}\",legend=levels,pch=c(1:m)+#{opthash["--legendMarkerSizeMod"]},col=c(1:m))"
    cmds << "    }"
    cmds << "    palette(\"default\")"
    cmds << "    }"
    cmds << "    title(paste(factor, scale, sep=\" - \"))"
    cmds << "}"
    cmds << ""
    cmds << "#http://rgm2.lab.nig.ac.jp/RGM2/R_man-2.9.0/library/BiodiversityR/R/rankabunplot.R"
    cmds << "`rankabunplotMOD` <-"
    cmds << "function(xr,addit=F,labels=\"\",scale=\"abundance\",scaledx=F,type=\"o\",xlim=c(min(xpos),max(xpos)),ylim=c(0,max(x[,scale])),specnames=c(1:5),...) {"
    cmds << "    x <- xr"
    cmds << "    xpos <- 1:nrow(x)"
    cmds << "    if (scaledx==T) {xpos <- xpos/nrow(x)*100}"
    cmds << "    if (scale==\"accumfreq\") {type <- \"o\"}"
    cmds << "    if (addit==F) {"
    cmds << "    if (scale==\"logabun\") {"
    cmds << "        plot(xpos,x[,\"abundance\"],xlab=\"species rank\",ylab=\"abundance\",type=type,bty=\"l\",log=\"y\",xlim=xlim,...)"
    cmds << "    }else{"
    cmds << "        plot(xpos,x[,scale],xlab=\"species rank\",ylab=scale,type=type,bty=\"l\",ylim=ylim,xlim=xlim,...)"
    cmds << "    }"
    cmds << "    }else{"
    cmds << "    if (scale==\"logabun\") {"
    cmds << "        points(xpos,x[,\"abundance\"],type=type,...)"
    cmds << "    }else{"
    cmds << "        points(xpos,x[,scale],type=type,...)"
    cmds << "    }"
    cmds << "    }"
    cmds << "    if (length(specnames) > 0) {"
    cmds << "    for (i in specnames) {"
    cmds << "        if (scale==\"logabun\") {"
    cmds << "        text(i+0.5,x[i,\"abundance\"],rownames(x)[i],pos=4)"
    cmds << "        }else{"
    cmds << "        text(i+0.5,x[i,scale],rownames(x)[i],pos=4)"
    cmds << "        }"
    cmds << "    }"
    cmds << "    }"
    cmds << "    if (labels!=\"\") {"
    cmds << "        if (scale==\"logabun\") {"
    cmds << "        text(1,x[1,\"abundance\"],labels=labels,pos=4)"
    cmds << "        }else{"
    cmds << "        text(1,x[1,scale],labels=labels,pos=4)"
    cmds << "        }"
    cmds << "    }"
    cmds << "}"

 
    #loop through each meta data value
    @metaArray.each{ |metaVal|
      #loop through each rank abundance method
      rankAbunMethods.each{ |rankAbunMethod|
        $stderr.puts "#{metaVal}-#{rankAbunMethod}"
        outputFile = outputDir + "#{metaVal}-#{rankAbunMethod}.pdf"

        #store pdf file
        pdfs << outputFile

        cmds << "pdf(file= \"#{outputFile}\", height=#{opthash["--height"]}, width=#{opthash["--width"]})"
        cmds << "RankAbun.1 <- rankabuncompMOD(CommunityDataset, y=EnvironmentalDataset, "
        cmds << "  factor='#{metaVal}', scale='#{rankAbunMethod}', legend=#{opthash["--legendBoolChar"]}, rainbow=#{opthash["--rainbow"]})"
        cmds << "dev.off()"
      }    
    }   
 
    #execute R commands and store output for species accumulation
    executeRcommands(cmds, "rankAbundanceCmds.R")

    #convert each pdf into PNG
    convertPDFtoPNG(pdfs)
  end

  def runRenyiProfile()
    renyiMethods = %w()
 
    outputDir = @outputDirectory + "/renyiProfilePlots/"
    #make output dierectory
    FileUtils.mkdir_p outputDir

    #array to store output pdfs for conversion
    pdfs = []

    #array to store R commands
    cmds = [] 

    cmds << "#http://rgm2.lab.nig.ac.jp/RGM2/R_man-2.9.0/library/BiodiversityR/R/renyiaccumresult.R"
    cmds << "`renyiaccumresult` <-"
    cmds << "function(x,y=\"\",factor,level,scales=c(0,0.25,0.5,1,2,4,8,Inf),permutations=100,...) {"
    cmds << "    if(class(y) == \"data.frame\") {"
    cmds << "        subs <- y[,factor]==level"
    cmds << "        for (q in 1:length(subs)) {"
    cmds << "            if(is.na(subs[q])) {subs[q]<-F}"
    cmds << "        }"
    cmds << "        x <- x[subs,,drop=F]"
    cmds << "        freq <- apply(x,2,sum)"
    cmds << "        subs <- freq>0"
    cmds << "        x <- x[,subs,drop=F]"
    cmds << "    }"
    cmds << "    result <- renyiaccum(x,scales=scales,permutations=permutations,...)"
    cmds << "    return(result)"
    cmds << "}"
    cmds << ""
    cmds << "#http://rgm2.lab.nig.ac.jp/RGM2/R_man-2.9.0/library/BiodiversityR/R/renyicomp.R"
    cmds << "`renyicompMOD` <-"
    cmds << "function(x,y,factor,sites=Inf,scales=c(0,0.25,0.5,1,2,4,8,Inf),permutations=100,plotit=T,...) {"
    cmds << "    groups <- table(y[,factor])"
    cmds << "    if (sites == Inf) {sites <- min(groups)}"
    cmds << "    m <- length(groups)"
    cmds << "    n <- max(groups)"
    cmds << "    s <- length(scales)"
    cmds << "    levels <- names(groups)"
    cmds << "    result <- array(NA,dim=c(m,s,6))"
    cmds << "    dimnames(result) <- list(level=levels,scale=scales,c(\"mean\",\"stdev\",\"min\",\"max\",\"Qnt 0.025\",\"Qnt 0.975\"))"
    cmds << "    names(dimnames(result)) <- c(factor,\"scale\",\"\")"
    cmds << "    for (i in 1:m) {"
    cmds << "       if (groups[i] == sites) {result[i,,1] <- as.matrix(renyiresult(x,y,factor,levels[i],scales=scales))}"
    cmds << "       if (groups[i] > sites) {result[i,,] <- renyiaccumresult(x,y,factor,levels[i],scales=scales,permutations=permutations)[sites,,]}"
    cmds << "    }"
    cmds << "    if (plotit==T) {renyiplotMOD(result[,,1],...)}"
    cmds << "    return(result)"
    cmds << "}"
    cmds << ""
    cmds << "#http://rgm2.lab.nig.ac.jp/RGM2/R_man-2.9.0/library/BiodiversityR/R/renyiplot.R"
    cmds << "`renyiplotMOD` <-"
    cmds << "function(xr,addit=F,pch=1,ylim=c(0,m),labelit=T,legend=T,col=1,cex=1,rainbow=F,evenness=F,...) {"
    cmds << "    x <- xr"
    cmds << "    x <- as.matrix(x)"
    cmds << "    p <- ncol(x)"
    cmds << "    n <- nrow(x)"
    cmds << "    m <- max(x,na.rm=T)"
    cmds << "    names <- colnames(x)"
    cmds << "    names <- as.factor(names)"
    cmds << "    pos <- -1"
    cmds << "    ylab <- \"H-alpha\""
    cmds << "    if(evenness==T) {"
    cmds << "        pos <- 1"
    cmds << "        ylab <- \"E-alpha\""
    cmds << "        x[,] <- x[,]-x[,1]"
    cmds << "        m <- min(x,na.rm=T)"
    cmds << "        ylim <- c(m,0)"
    cmds << "    }"
    cmds << "    if(addit==F) {"
    cmds << "        plot(names,rep(pos,p),xlab=\"alpha\",ylab=ylab,ylim=ylim,bty=\"l\",...)"
    cmds << "    }"
    cmds << "    if (n > 25) {"
    cmds << "        warning(\"Symbol size was kept constant as there were more than 25 profiles (> number of symbols that are currently used in R)\")"
    cmds << "        rainbow <- T"
    cmds << "    }"
    cmds << "    if (rainbow==T && n > 1) {"
    cmds << "        palette(rainbow(n))"
    cmds << "        for (i in 1:n) {"
    cmds << "            if (n<26) {points(c(1:p),x[i,],pch=i,col=i,cex=cex,type=\"o\")}"
    cmds << "            if (n>25) {points(c(1:p),x[i,],pch=19,col=i,cex=cex,type=\"o\")}"
    cmds << "            if (labelit==T) {"
    cmds << "                text(1,x[i,1],labels=rownames(x)[i],pos=2,col=i,cex=cex)"
    cmds << "                text(p,x[i,p],labels=rownames(x)[i],pos=4,col=i,cex=cex)"
    cmds << "            }"
    cmds << "        }"
    cmds << "        if (legend==T && n<26) {legend(\"#{opthash["--legendPosition"]}\",legend=rownames(x),pch=c(1:n)+#{opthash["--legendMarkerSizeMod"]},col=c(1:n))}"
    cmds << "        if (legend==T && n>25) {legend(\"#{opthash["--legendPosition"]}\",legend=rownames(x),pch=rep(19,n),col=c(1:n))}"
    cmds << "    }else{"
    cmds << "        colors <- c(#{opthash["--colors"]})"
    cmds << "        palette(colors)"
    cmds << "        for (i in 1:n) {"
    cmds << "            #points(c(1:p),x[i,],pch=pch,col=col,cex=cex,type=\"o\")"
    cmds << "            #if (labelit==T) {"
    cmds << "            #    text(1,x[i,1],labels=rownames(x)[i],pos=2,col=col,cex=cex, offset=8)"
    cmds << "            #    text(p,x[i,p],labels=rownames(x)[i],pos=4,col=col,cex=cex)"
    cmds << "            #}"
    cmds << "            if (n<26) {points(c(1:p),x[i,],pch=i,col=i,cex=cex,type=\"o\")}"
    cmds << "            if (n>25) {points(c(1:p),x[i,],pch=19,col=i,cex=cex,type=\"o\")}"
    cmds << "            if (labelit==T) {"
    cmds << "                text(1,x[i,1],labels=rownames(x)[i],pos=2,col=i,cex=cex, offset=#{opthash["--renyiOffset"]})"
    cmds << "                #text(p,x[i,p],labels=rownames(x)[i],pos=4,col=i,cex=cex)"
    cmds << "            }"
    cmds << "        }"
    cmds << "        #if (legend==T) {legend(\"#{opthash["--legendPosition"]}\",legend=rownames(x),pch=c(1:n)+#{opthash["--legendMarkerSizeMod"]})}"
    cmds << "        if (legend==T && n<26) {legend(\"#{opthash["--legendPosition"]}\",legend=rownames(x),pch=c(1:n)+#{opthash["--legendMarkerSizeMod"]},col=c(1:n))}"
    cmds << "        if (legend==T && n>25) {legend(\"#{opthash["--legendPosition"]}\",legend=rownames(x),pch=rep(19,n),col=c(1:n))}"
    cmds << "    }"
    cmds << "    palette(\"default\")"
    cmds << "}"

    evenness = "F"
    evennessName = ""

    #loop through each meta data value
    @metaArray.each{ |metaVal|
      #loop through metaVals twice for normal and "evenness"
      for i in (0..1)
        if i == 0
          evenness = "F"
          evennessName = ""  
        else
          evenness = "T"
          evennessName = "evenness-"
        end
        $stderr.puts "#{metaVal}-#{evennessName}renyi"
        outputFile = outputDir + "#{metaVal}-#{evennessName}renyi.pdf"

        #store pdf file
        pdfs << outputFile

        cmds << "pdf(file= \"#{outputFile}\", height=#{opthash["--height"]}, width=#{opthash["--width"]})"

        cmds << "Renyi.1 <- renyicompMOD(CommunityDataset, evenness=#{evenness},
  y=EnvironmentalDataset, factor='#{metaVal}', scales=c(#{opthash["--renyiScale"]}), permutations=#{opthash["--permutations"]}, legend=#{opthash["--legendBoolChar"]})"
        cmds << "title(\"#{metaVal}-#{evennessName}Renyi\")"
        cmds << "dev.off()"
      end
    }    
  
    #execute R commands and store output for species accumulation
    executeRcommands(cmds, "renyiProfileCmds.R")

    #convert each pdf into PNG
    convertPDFtoPNG(pdfs)

  end

  #convert pdf's into PNGs
  # input: array list of fully qualified paths to pdf files
  def convertPDFtoPNG(pdfList)
    pdfList.each{ |pdfFile|
      pdfFile.strip!
      puts convertCmd = "convert -density #{opthash["--pngDensity"]} #{pdfFile} #{pdfFile.gsub(/pdf$/, "PNG")}"
      `#{convertCmd}`
      `rm -f #{pdfFile}`
    }

  end

  def removeSingletons()
    if opthash["--removeSingletons"].to_i == 1
      removeSingletonsFile = @communityFile + ".remove.singletons"

      #get first two lines of community matrix file
      cRead = File.open(@communityFile, "r")
      line1 = cRead.gets
      line2 = cRead.gets
      cRead.close()
    
      #check for new qiime header and then tax label
      stringCheck1 = "\# QIIME\ v1.2.0\ OTU\ table"
      #stringCheck1 ="\#Full \OTU\ Counts"
      stringCheck2 = "Consensus\ Lineage"

      headerCheckBool = 0
      otuLabelCheckBool = 0

      #check for occurrence of OTU header (qiime 1.2.0 header)
      headerCheckBool = 1 if line1 =~ /#{stringCheck1}/
      #check for occurrence of otu type file
      otuLabelCheckBool = 1 if line1 =~ /#{stringCheck2}/ || line2 =~ /#{stringCheck2}/
    
        
      w = File.open(removeSingletonsFile, "w")
      r = File.open(@communityFile, "r")

      if headerCheckBool == 1
        w.puts r.gets
      end

      header = r.gets
      w.puts header
   
      keepCount = 0

      r.each{ |line|
        line.strip!
        #split line into array based on tab
        spl = line.split("\t")
        #delete OTU label
        spl.delete_at(0)
        #delete tax label if it's present
        spl.delete_at(spl.length-1) if otuLabelCheckBool == 1

        #keep track of row sum
        sum = 0
        spl.each{ |val|
          sum += val.to_i
        }
        
        #print line if it is greater than 1
        if sum > 1
          w.puts line          
          keepCount += 1
        end

      }

      w.close()
      r.close()
      #point communityFile to otu table with removed singletons
      @communityFile = fep(removeSingletonsFile)      
    end
  end

  def work()
    #set default settings via default settings file 
   # setDefaultSettings()
 
    #store meta data values into an array
    #storeMetaDataArray(@metaDataListFile)
    storeMetaDataArrayFromSettings()
 
    #remove singletons from OTU table if applicable in cmd line args
    removeSingletons()

    #check that community and environmental files are in proper format
    #  and produce new versions if necessary
    fixOriginalInput_CommunityFile()
    fixOriginalInput_EnvironmentalFile()

    #set default settings via default settings file 
    #setDefaultSettings()

    #set custom settings via custom settings file
    #setCustomSettings()

    #format special R data formatting variables
    fixRvars()

    #check that input data is valid before any computational work
    # exit if incompatible data sets
    checkInputDataSets()
    
    #get and store sample header for axis labeling, etc.
    getSampleHeader()

    #perform diversity indices
    runDiversityIndices()

    #perform species accumulation curves (i.e. richness)
    runSpeciesAccumulationCurvesRichness()

    #perform rank abundance curves
    runRankAbundance()

    #perform Renyi profile
    runRenyiProfile()

  end


end

#check for proper usage and exit if necessary
settinghash=processArguments()

#initialize input data
alphaDiv = AlphaDiversity.new(settinghash)

#perform alpha diversity pipeline via work function
alphaDiv.work()
exit 0
