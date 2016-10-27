#!/usr/bin/env ruby
require 'fileutils'
require "brl/util/textFileUtil"
require "brl/util/util"
require 'simple_xlsx'

DEBUG = 0

def processArguments()
    # We want to add all the prop_keys as potential command line options
      optsArray = [ ['--inputmatrix','-i', GetoptLong::REQUIRED_ARGUMENT],
                    ['--metadata','-m', GetoptLong::REQUIRED_ARGUMENT],
                    ['--outputFolder','-o', GetoptLong::REQUIRED_ARGUMENT],
                    ['--sortby','-s', GetoptLong::REQUIRED_ARGUMENT],
                    ['--minPval','-p', GetoptLong::REQUIRED_ARGUMENT],
                    ['--minAdjPval','-a', GetoptLong::REQUIRED_ARGUMENT],
                    ['--minFoldChange' ,'-f', GetoptLong::REQUIRED_ARGUMENT],
                    ['--minAveExp' ,'-e', GetoptLong::REQUIRED_ARGUMENT],
                    ['--minBval' ,'-b', GetoptLong::REQUIRED_ARGUMENT],
                    ['--testMethod' ,'-T', GetoptLong::REQUIRED_ARGUMENT],
                    ['--adjustMethod' ,'-A', GetoptLong::REQUIRED_ARGUMENT],
                    ['--multiplier','-x', GetoptLong::REQUIRED_ARGUMENT],
                    ['--printTaxonomy','-t', GetoptLong::REQUIRED_ARGUMENT],
                    ['--normalize' ,'-n', GetoptLong::REQUIRED_ARGUMENT],
                    ['--metaDataColumns' ,'-c', GetoptLong::REQUIRED_ARGUMENT],
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
   Microbiome workbench run limma pipeline 
   
  COMMAND LINE ARGUMENTS:
                    --inputmatrix               |  -i => input_matrix_file.txt
                    --metadata                  |  -m => inpu_meta_data.tsv
                    --outputFolder              |  -o => output_folder/
                    --sortby                    |  -s => logFC, AveExpr, t, P, p, B, or none
                    --minPval                   |  -p => 0.05
                    --minAdjPval                |  -a => 0.05
                    --minFoldChange             |  -f => 10
                    --minAveExp                 |  -e => 5
                    --minBval                   |  -b => -5
                    --testMethod                |  -T => separate, global, hierarchical, or nestedF
                    --adjustMethod              |  -A => none, BH, fdr, BY, holm, hochberg, hommel, or bonferroni
                    --multiplier                |  -x => 100000
                    --printTaxonomy             |  -t => 0 or 1
                    --normalize                 |  -n => 0 (none), 1 (percentage normalization), 2 (quantile normalization)
                    --metaDataColumns           |  -c => \"body_site,pH,BMI\"

usage:
   run_limma.rb -i matrix.txt -m metadata.tsv -o outputFolder/ -s B -p 0.05 -a 0.05 -f 10 -e 5 -b -5 -T separate -A fdr -x 100000 -t 1 -n 1 -c \"body_site\"

";
   exit;
end

class Limma
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
    @metaFile = File.expand_path(opthash["--metadata"])

    @outputDirectory = File.expand_path(opthash["--outputFolder"])

    #create output directory
    FileUtils.mkdir_p @outputDirectory

    #store taxonomy with OTU id
    @tax = Hash.new(0)

  end

  def qNorm()
    flag = 0

    fileExt = File.extname(@matrixFile)
    fileStub = @outputDirectory + "/" + File.basename(@matrixFile)

    outFileAgain = ""
    #if there is a file extension
    if fileExt != ""
      outFileAgain = fileStub.gsub(fileExt, "-qnorm.txt")
    else
      outFileAgain = fileStub + "-qnorm.txt"
    end

    #determine if we can figure out if we have accession/taxonomy column
    r = File.open(@matrixFile, "r")

    #check to see if taxonomy is at beginning or end of line
    line1 = r.gets
    line2 = r.gets

    #we can set this to skip a particular amount of lines depending on the
    # type of input, here we will ignore the QIIME line
    numLinesToSkip = 0
    numLinesToSkip += 1 if line1 =~ /\#\ QIIME/ || line2 =~ /\#\ QIIME/ || line1 =~ /^\#Full/ || line2 =~ /^\#Full/

    taxCheckBeginning = ""
    taxCheckEnd = ""

    lineCount = 0
    #store beginning and end of first 500 lines to check for possible taxonomy
    #  because we might not always have predictable input
    r.each{ |line|
      lineCount += 1
      next if lineCount < 2
      spl = line.split("\t")
      taxCheckBeginning += spl[0]
      taxCheckEnd += spl[spl.length-1].strip
      lineCount += 1
      break if lineCount > 500
    }

    #check first and last entries for semicolons or the 'ConsensusLineage' tag  
    if taxCheckBeginning =~ /\;/
      #tax is at beginning, meaning phylogenetic split OTU table
      flag = 1
    #elsif taxCheckEnd =~ /\;/ || line1 =~ /ConsensusLineage/ || line2 =~ /ConsensusLineage/
    #8-17-11 look for just Consensus and alpha characters excluding na NA
    elsif taxCheckEnd =~ /\;/ || taxCheckEnd =~ /[b-mB-M]/ || taxCheckEnd =~ /[o-zO-Z]/ || line1 =~ /Consensus/ || line2 =~ /Consensus/
      #tax is at end, meaning full OTU table
      flag = 2
    #else we do not have taxonomy, just OTU table
    else
      flag = 3
    end
    r.close

    headerFixRemoveTaxFileTmp = @outputDirectory + "/" + File.basename(@matrixFile) + ".fixTmp"
    #get header so we can check if we have to re-write file
    r = File.open(@matrixFile, "r")
    #skip a number of lines that we should ignore
    for i in (0..numLinesToSkip-1)
      r.gets
    end

    header = r.gets
    #remove potential trailing tab
    header.gsub!(/\t$/,"")
    spl = header.split("\t")

    headerSize = spl.length

    accessionColHeader = ""

    w = File.open(headerFixRemoveTaxFileTmp, "w")      
    #if we have a non-nil entry we have to re-write file with different header
    if spl[0] != ""
      $stderr.print "\nFixing table with entry in [0][0]...\t"
      spl.delete_at(0)
      accessionColHeader = spl[spl.length-1] if flag == 2
      spl.delete_at(spl.length-1) if flag == 2
      w.puts "\t#{spl.join("\t")}"
    else
      $stderr.print "\nFixing table for quantile normalization...\t"
      accessionColHeader = spl[spl.length-1] if flag == 2
      spl.delete_at(spl.length-1) if flag == 2 
      w.puts spl.join("\t") 
    end

    #need to store and remove taxonomy if it exists
    accessionArr = []


    #loop through rest of lines
    r.each_with_index{ |line, count|
      spl2 = []
      #remove potential trailing tabs
      line.gsub!(/\t$/,"")
      #print out line except for last column
      if flag == 2
        spl2 = line.split("\t")
        accessionArr.push(spl2[spl2.length-1])
        spl2.delete_at(spl2.length-1)
        #w.puts spl2.join("\t") 
      else
        spl2 = line.split("\t")
        #w.puts line
      end

      if spl2.size == headerSize
        w.puts spl2.join("\t")
      else
        #$stderr.puts "ignoring line #{count} because it has #{spl2.size} elements, not #{headerSize}"
        #actually we should fill up rows that end in blanks so we can treat
        # them like the other blank values
        diff = headerSize - spl2.size
        if diff > 0
          outLine = spl2.join("\t").strip
          for i in (0..diff)
            outLine += "\t"
          end
          w.puts outLine
        else 
          $stderr.puts "ignoring line #{count} because it has #{spl2.size} elements, not #{headerSize}"
        end
      end
    }
      
    @matrixFile = headerFixRemoveTaxFileTmp 
    $stderr.puts "DONE"
    #end

    w.close()
    r.close()
    tmpQnormFile = outFileAgain + ".tmp"
    
    rCMD = "
library(preprocessCore)
#arrayData <- read.table(\"#{@matrixFile}\")
arrayData <- read.table(\"#{@matrixFile}\", row.names=1, header=TRUE, sep=\"\\t\", na.strings= \"NA\")
arrayDataMatrix <- as.matrix(arrayData)
arrayDataMatrixQuantile <- normalize.quantiles(arrayDataMatrix, copy=TRUE)
rownames(arrayDataMatrixQuantile) <- rownames(arrayDataMatrix)
colnames(arrayDataMatrixQuantile) <- colnames(arrayDataMatrix)

write.table(arrayDataMatrixQuantile, file=\"#{tmpQnormFile}\", sep=\"\\t\", row.names=TRUE, col.names=TRUE, quote=FALSE)
"
    rFile = @outputDirectory + "/qNorm.R"
    rW = File.open(rFile, "w")
    rW.puts rCMD
    rW.close

    $stderr.print "Running quantile normalization...\t"
    #execute R command
    `R --vanilla < #{rFile}`
    $stderr.puts "DONE"

    $stderr.print "Post-processing of qnorm file...\t"

    #write to final output file 
    w = File.open(outFileAgain, "w")

    #loop through file for final output
    r = File.open(tmpQnormFile, "r")
    #skip a number of lines that we should ignore
    for i in (0..numLinesToSkip-1)
      r.gets
    end

    header = r.gets
    #puts header 
    if flag == 2
      w.puts "\t#{header.strip}\t#{accessionColHeader}"
    else
      w.puts "\t#{header}"
    end

    lineCount = 0
    r.each{ |line|
      #if we had accession we need to put it back
      if flag == 2
        w.puts line.strip + "\t" + accessionArr[lineCount]
      #else we can simply proceed forward
      else
        w.puts line
        #outFileAgain = tmpQnormFile
      end
      lineCount += 1
    }
    
    $stderr.puts "DONE"
    w.close()
    $stderr.print "Deleting temporary files...\t"
    `rm -f #{headerFixRemoveTaxFileTmp}`
    `rm -f #{tmpQnormFile}`
    $stderr.puts "DONE"
    @matrixFile = outFileAgain
  end

  def prepareMatrix()
    #store unordered OTU list
    @unorderedOTUlist = []

    count = 0
    flag = 0
    @numRows = 0

    #store sample order so we can match it in the design file
    @sampleOrder = []

    normFlag = @opthash["--normalize"].to_i
    printTax = @opthash["--printTaxonomy"].to_i

    if normFlag == 2
      $stderr.print "\nPreparing matrix for input for quantile normalization...\t"
    end
    #perform quantile normalization idependently 
    qNorm() if normFlag == 2

    $stderr.print "\nPreparing matrix for input into limma...\t"

    r = File.open(@matrixFile, "r")
    #set cut off for basic filtering - not implemented yet
    #cutOff = cutoff.to_f

    multiplier = opthash["--multiplier"]
    
    #check to see if taxonomy is at beginning or end of line
    line1 = r.gets
    line2 = r.gets

    #we can set this to skip a particular amount of lines depending on the
    # type of input, here we will ignore the QIIME line
    numLinesToSkip = 0
    numLinesToSkip += 1 if line1 =~ /\#\ QIIME/ || line2 =~ /\#\ QIIME/ || line1 =~ /^\#Full/ || line2 =~ /^\#Full/

    taxCheckBeginning = ""
    taxCheckEnd = ""    

    lineCount = 0
    #store beginning and end of first 500 lines to check for possible taxonomy
    #  because we might not always have predictable input
    r.each{ |line|
      lineCount += 1
      next if lineCount < 2
      spl = line.split("\t")
      taxCheckBeginning += spl[0]
      taxCheckEnd += spl[spl.length-1].strip
      lineCount += 1
      break if lineCount > 500
    }
        
    #check first and last entries for semicolons or the 'ConsensusLineage' tag  
    if taxCheckBeginning =~ /\;/
      #tax is at beginning, meaning phylogenetic split OTU table
      flag = 1
    #elsif taxCheckEnd =~ /\;/ || line1 =~ /ConsensusLineage/ || line2 =~ /ConsensusLineage/
    #8-17-11 look for just Consensus and alpha characters excluding na NA
    elsif taxCheckEnd =~ /\;/ || taxCheckEnd =~ /[b-mB-M]/ || taxCheckEnd =~ /[o-zO-Z]/ || line1 =~ /Consensus/ || line2 =~ /Consensus/
      #tax is at end, meaning full OTU table
      flag = 2
    #else we do not have taxonomy, just OTU table
    else
      flag = 3
    end
    r.close

    #re-open the file for fixing and potentially normalization steps
    r = File.open(@matrixFile, "r")
    fileExt = File.extname(@matrixFile)

    fileStub = @outputDirectory + "/" + File.basename(@matrixFile)

    #if there is a file extension
    if fileExt != ""
      if normFlag == 1
        outFileAgain = fileStub.gsub(fileExt, "-fixed-normalized.txt")
      else
        outFileAgain = fileStub.gsub(fileExt, "-fixed.txt")
      end
    else
      if normFlag == 1
        outFileAgain = fileStub + "-fixed-normalized.txt"
      else
        outFileAgain = fileStub + "-fixed.txt"
      end
    end

    #open file for writing
    w = File.open(outFileAgain, "w")

    #skip a number of lines
    for i in (0..numLinesToSkip-1)
      r.gets
    end
    
    #get col headers
    # try to also account for possible trailing tabs
    #header = r.gets
   
    #header = r.gets.strip
    header = r.gets.gsub(/\t$/,"")
   
    #if we have taxonomy print all but the last label
    if flag == 2
      spl = header.strip.split("\t")
      spl.delete_at(spl.length-1)
      header = spl.join("\t")
    end

    #print header, but make sure that it beings with alpha
    hCount = 0
    header.split("\t").each{ |hval|
      hval.strip!
      hval = "X" + hval if hval !~ /^[a-zA-Z]/

      hval = "X" if hCount == 0 

      w.print "\t" if hCount > 0
      w.print hval

      #store sample order for design file, ignore first entry
      @sampleOrder.push(hval) if hCount > 0
      hCount += 1
    }
    w.puts

    
    #determine how many rows we have
    headerArr = header.split("\t")
    headerCount = 0
    #headerCount = headerArr.length - 1 if flag == 2
    #headerCount = headerArr.length if flag == 1 || flag == 3
    headerCount = headerArr.length
    allArrs = []
    allArrSums = []
    allTax = []


    #initialize arrays and sums
    for i in (0..headerCount)
      tmpArr = []
      allArrs << tmpArr
      allArrSums.push(0)
    end
   
    count = 0
    #loop through each line in file after header line
    r.each{ |line|
      #don't need to complete this work if we aren't normalizing
      #  still need the counts, so let it run anyways for now
      #break if normFlag == 0

      spl = line.split("\t")
      internalCount = 0
      spl.each{ |val|
        break if val == nil
        #store sums for each column as well as taxonomy for each row
        if flag == 2
          if internalCount == 0
            allArrs[internalCount].push(val.to_s)
            internalCount += 1
          elsif internalCount <= headerCount -1
            allArrs[internalCount].push(val.to_f)
            allArrSums[internalCount] = allArrSums[internalCount].to_i + val.to_i
            internalCount += 1
          else
            allTax.push(val)
            @tax[spl[0].to_s] = val.strip
            #break
          end
        elsif flag == 3 
          #store sums for each column
          if internalCount == 0
            allArrs[internalCount].push(val.to_s)
            internalCount += 1
          elsif internalCount <= headerCount -1
            allArrs[internalCount].push(val.to_f)
            allArrSums[internalCount] = allArrSums[internalCount].to_i + val.to_i
            internalCount += 1
          end
        end
      }
      count += 1
    }
 
    count = 0
    count = -1 if flag == 2
    lineNum = 0
    
    arrSize = allArrs[0].length
   
    #loop through each row
    for rowNum in (0...arrSize)
      count = 0

      #store unordered OTU list
      @unorderedOTUlist.push(allArrs[0][rowNum])

      if flag == 2 || flag == 3
        w.print "#{allArrs[0][rowNum]}\t"

        for colNum in (1...headerCount)
          #val = allArrs[colNum][rowNum].to_i
          val = allArrs[colNum][rowNum].to_f
          if val == 0
            normVal = 0
          else
            #divide value by the column sum
            normVal = val.to_f / allArrSums[colNum].to_f
          end

          #multiple each normalized value by the provided multipier
          normVal = normVal * multiplier.to_f

          #print tab after each value, excluding the first entry
          w.print "\t" if count > 0

          #if we are percentile normalzing 
          if normFlag == 1
            #round value to obtain whole number
            w.print sprintf('%0.f', normVal)
          else
            #w.print val
            w.print convertEval(val)
          end
          count += 1
        end
        #if we want taxonomy
        # actually we will not want taxonomy here, it will crash pipeline,
        # use this further down the road
=begin
        if printTax == 1
          w.puts allTax[rowNum]
        else
          w.puts
        end
=end
        w.puts
      end
      lineNum += 1
      #break
    end
    @numRows = lineNum

    r.close()
    w.close()

    #delete intermediary file if we did quartile normalization
    if normFlag == 2
      `rm #{@matrixFile}`
    end

    #set matrix file name to normalized file
    @matrixFile = outFileAgain

    
  end

  def makeDesign(metaDataValue)
    fileExt = File.extname(@metaFile)
    fileStub = @outputDirectory + "/" + File.basename(@metaFile)
    #if there is a file extension
    if fileExt != ""
      @designFile = fileStub.gsub(fileExt, "-design.txt")
    else
      @designFile = fileStub + "-design.txt"
    end
    $stderr.puts @designFile if DEBUG == 1
    #open design file for writing
    w = File.open(@designFile, "w")
    #open meta data file for reading
    r = File.open(@metaFile, "r")
    header = r.gets
    header.gsub!(/\t$/,"")
    splHeader = header.strip.split("\t")
    #identify column where meta data exists
    columnNum = splHeader.index(metaDataValue)
    #hash to store sample => meta data
    sampHsh = Hash.new(0)

    #hash to store meta data and count
    metaHsh = Hash.new(0)

    #array to store meta data values
    metaArr = []

    #loop through meta data to store sample and meta data
    r.each{ |line|
      spl = line.strip.split("\t")
      #line.gsub!(/\t$/,"")
      #puts spl = line.strip.split("\t")
      metaVal = spl[columnNum].to_s
      #append an 'x' in front of meta value if it is 0-9
      metaVal = "X" + metaVal if metaVal !~ /^[a-zA-Z]/
      storeName = spl[0]
      storeName = "X" + storeName if storeName !~ /^[a-zA-Z]/

      #sampHsh[spl[0]] = metaVal

      #have to also convert '-' to '.' or we will have crash
      storeName.gsub!(/\-/,".")

      sampHsh[storeName] = metaVal
      metaHsh[metaVal] += 1
      metaArr.push(metaVal)
    }
    r.close()

    #print out header
    w.puts "sample\tTarget"
    #sampHsh.each{ |k,v|
    #  sampName = k
    #  sampName = "X" + sampName if sampName !~ /^[a-zA-Z]/
    #  w.puts "#{sampName}\t#{v}"
    #}

    #loop through sample order and lookup meta data based on hash
    @sampleOrder.each{ |sampleName|
      tmpName = sampleName
      tmpName = "X" + tmpName if tmpName !~ /^[a-zA-Z]/
      #have to also convert '-' to '.' or we will have crash
      tmpName.gsub!(/\-/,".")
      w.puts "#{tmpName}\t#{sampHsh[tmpName]}"
    }
    
    w.close()

    #get unique list
    metaArr.uniq!

    @metaComboArr = []
    #loop through each value and make exhaustive combinations
    #  no same value or reverse value combinations accepted
    metaArr.each{ |val1|
      metaArr.each{ |val2|
        tmp1 = val1
        tmp2 = val2
        if val1 < val2
          tmp1 = val2
          tmp2 = val1
        end

        @metaComboArr.push("#{tmp1}-#{tmp2}") if tmp1 != tmp2
      }
    }

    @metaComboArr.uniq!

    metaDoubleComboArr = []
    #loop through each value and make exhaustive combinations of combinations
    #  no same value or reverse value combinations accepted
    tmpArr1 = @metaComboArr
    for i in (0...@metaComboArr.length)
      tmpArr2 = tmpArr1

      list = ""
      tmpArr1.each_with_index{ |val, count|
        list +=  "," if count > 0
        list += val
      } 
      metaDoubleComboArr.push(list)
 
      tmpArr2.push(tmpArr1[0])
      tmpArr2.delete_at(0)

      tmpArr1 = tmpArr2
    end


    returnArr = []
    returnArr.push(metaArr)
    returnArr.push(@metaComboArr)
    returnArr.push(metaDoubleComboArr)

    return returnArr

  end

  def limma(metaDataName, metaDataArrays)
    #store unordered, unsorted F.p.value
    @fpvalueList = []

    #store F.p.value with OTU id
    @fpvalue = Hash.new(0)

    #store matrix results with OTU id
    @matrixResults = Hash.new(0)

    #store p value results (correspond to matrix results) with OTU id
    @pResults = Hash.new(0)

    #array for storing filtered table files
    @filteredTablesArr = []

    #store ordered OTU list based on fit2$gene sort
    @orderedOTUlist = []

    #array contains list of meta data values
    @metaValsArr = metaDataArrays[0]
    #array contains all unique combinations of meta data values
    @metaComboArr = metaDataArrays[1]
    #array contains list of all combinations of combinations of meta data values
    @metaListArr = metaDataArrays[2]

    metaDataString = ""

    @metaValsArr.each_with_index{ |val,count|
      metaDataString += ", " if count > 0
      metaDataString += "\"#{val}\""
    }

    #setup output file name
    fileStub =  @outputDirectory + "/" + metaDataName

    #store raw out table files
    rawOutArr = []    
    #store pdf files
    vennPdfFilesArr = []
    
    fitGenesFilesArr = []

    rFile = fileStub + ".R"
    $stderr.puts rFile if DEBUG == 1
    w = File.open(rFile, "w")
    w.puts "
	library(limma)
	data <- read.table(\"#{@matrixFile}\", row.names=1, header=TRUE, sep=\"\\t\", na.strings= \"NA\")
	targets <- readTargets(file=\"#{@designFile}\")

	f <- factor(targets$Target, levels = c(#{metaDataString}))
	design <- model.matrix(~0 + f)
	colnames(design) <- c(#{metaDataString})

	fit <- lmFit(data, design)"

    fitGenesFile = "#{fileStub}-fitGenes.out"
    mResultsFile = "#{fileStub}-matrix-results.tsv"
    pResultsFile = "#{fileStub}-p-results.tsv"
    fpResultsFile = "#{fileStub}-fpvalues.tsv"
    sResultsFile = "#{fileStub}-summary-results.tsv"
    cResultsFile = "#{fileStub}-contrasts.tsv"
    dResultsFile = "#{fileStub}-design.tsv"
    vpdfFile = "#{fileStub}-vennDiagram.pdf"
    
    reportSummaryXLSXfile = "#{fileStub}-Multi-Comparison-Report.xlsx"
    reportSummaryTSVfile = "#{fileStub}-Multi-Comparison-Report.tsv"
    filteredTablesXLSXfile = "#{fileStub}-Filtered-Tables.xlsx"

    @metaListArr.each{ |list|
      spl = list.split(",")
      #name file based on first comparison entry
      rawOutFile = "#{fileStub}-#{spl[0]}-raw.out"
      rawOutArr.push(rawOutFile)
      
      w.puts "
	contrast.matrix <- makeContrasts(#{list}, levels = design)

	fit2 <- contrasts.fit(fit, contrast.matrix)
	fit2 <- eBayes(fit2)

        tt <- topTable(fit2, coef = 1, adjust.method = \"#{@opthash["--adjustMethod"]}\", number = #{@numRows}, sort.by=\"#{@opthash["--sortby"]}\")

        mat <- matrix(unlist(tt), ncol=7, byrow=FALSE)
        write(mat, file=\"#{rawOutFile}\", sep=\"\\t\")
	"
    }

    w.puts "
	results <- decideTests(fit2, method=\"#{@opthash["--testMethod"]}\", adjust.method=\"#{@opthash["--adjustMethod"]}\", p.value=#{@opthash["--minAdjPval"]}, lfc=#{@opthash["--minFoldChange"]})

	write.table(unclass(results), file=\"#{mResultsFile}\", sep=\"\\t\")

	p.value <- as.matrix(fit2$p.value)
	for (j in 1:ncol(p.value)) p.value[, j] <- p.adjust(p.value[,j], method =\"#{@opthash["--adjustMethod"]}\")
	tab <- list()
	tab$Genes <- fit2$genes
	tab$p.value <- p.value

	write.table(tab$p.value, file=\"#{pResultsFile}\", sep=\"\\t\")

	write.table(fit2$F.p.value, file=\"#{fpResultsFile}\", sep=\"\\t\")
        write.table(fit2$contrasts, file=\"#{cResultsFile}\", sep=\"\\t\")
        write.table(fit2$design, file=\"#{dResultsFile}\", sep=\"\\t\")

        summary <- summary(results)

        write.table(summary, file=\"#{sResultsFile}\", sep=\"\\t\")
	"

    #produce venn diagram if we have 3 or less values
    if @metaValsArr.size < 4
      w.puts "
        pdf(file= \"#{vpdfFile}\", height=7, width=7)
        vennDiagram(results)
        dev.off()
	"
    end

    w.puts "
	o <- order(fit2$F.p.value)
	fitGenes <- fit2$genes[o[1:#{@numRows}], ]
	mat2 <- matrix(unlist(fitGenes), ncol=1, byrow=FALSE)
        write(mat2, file=\"#{fitGenesFile}\", sep=\"\\t\")
	"

    w.close()


    $stderr.print "Running limma for #{metaDataName}...\t"
    cmd="R --vanilla < #{rFile}"
    $stderr.puts cmd
    system(cmd)

    #if we have 3 or less values produce venn diagram PNG from pdf
    if @metaValsArr.size < 4
      #convert pdf to PNG
      `convert -density 400 #{vpdfFile} #{vpdfFile.gsub(/pdf$/, "PNG")}`

      #remove pdf file
      `rm -f #{vpdfFile}`
    end
    $stderr.puts "DONE"
    $stderr.print "Generating flat text files...\t"

    #store names of processed raw files
    tableFiles = []

    #format each raw table output into columns
    rawOutArr.each{ |rawOutFile|
      #tableFiles.push(processRawFileIntoTable(rawOutFile, 0))
      processRawFileIntoTable(rawOutFile, 0) 
      tableFiles.push(processRawFileIntoTable(rawOutFile, 1))

      #delete raw output file
      `rm -f #{rawOutFile}`
    }

    #add tax labels to fit gene list if applicable
    if @opthash["--printTaxonomy"].to_i == 1
      processFitGeneListWithTaxonomy(fitGenesFile)
      #`rm -f #{fitGenesFile}`
    end

    #store otus in order of fit genes output
    File.open(fitGenesFile, "r").each{ |line|
      @orderedOTUlist.push(line.strip!.to_s)
    } 

    #store fit2$F.p.value into list
    r = File.open(fpResultsFile, "r")
    r.gets
    r.each{ |line|
      val = line.strip.split("\t")[1].to_f

      #convert val to long decimal for compatibility into excel
      @fpvalueList.push(convertEval(val))
      
    } 
    r.close()

    #store fit2$F.p.value into hash for formal output
    @fpvalueList.each_with_index{ |fp,count|
      @fpvalue[@unorderedOTUlist[count].to_s] = fp
    } 

    #store matrix results into hash for formal output
    r = File.open(mResultsFile, "r")
    matrixResultsHeader = r.gets
    r.each{ |line|
      spl = line.strip.split("\t")
      otu = spl[0].gsub(/\"/,"")
      spl.delete_at(0)
      storeVal = spl.join("\t")
      @matrixResults[otu.to_s] = storeVal      

    }
    r.close()

    #store p value results (corresponds to matrix results) into hash for output
    r = File.open(pResultsFile, "r")
    pResultsHeader = r.gets
    r.each{ |line|
      spl = line.strip.split("\t")
      otu = spl[0].gsub(/\"/,"")
      spl.delete_at(0)
      outVal = ""
      internalLoopCount = 0
      spl.each{ |val|
        convertedVal = convertEval(val.to_f)
        outVal += "\t" if internalLoopCount > 0
        outVal += convertedVal
        internalLoopCount += 1
      }
      @pResults[otu.to_s] = outVal
    }
    r.close()

    otuID = "0"

    wt = File.open(reportSummaryTSVfile, "w")
    
    header = "ID\tAccession\tF.p.value\t#{matrixResultsHeader.strip}\t#{pResultsHeader.strip}"

    lineArr = []

    hCount = 0
    header.split("\t").each{ |hVal|
      wt.print "\t" if hCount > 0
      wt.print hVal
      hCount += 1
    }
    wt.puts

    #loop through each OTU in order of f.p.value
    @orderedOTUlist.each{ |otuID|
      wt.print "#{otuID}\t"
      wt.print "#{@tax[otuID]}\t"
      wt.print "#{@fpvalue[otuID]}\t"

      @matrixResults[otuID].split("\t").each{ |mVal|
        wt.print "#{mVal}\t"
      }

      pCount = 0
      @pResults[otuID].split("\t").each{ |pVal|
        wt.print "\t" if pCount > 0
        wt.print "#{pVal}"
        pCount += 1
      }
      wt.puts

    }
    wt.close()

    fileArr = []
    fileArr.push(reportSummaryTSVfile)
    fileArr.push(sResultsFile)
    fileArr.push(cResultsFile)
    fileArr.push(dResultsFile)

    $stderr.puts "DONE"
    $stderr.print "Generating XLSX output files...\t"
    #convert tsv file into xlsx
    makeXlsx(reportSummaryXLSXfile, fileArr)

    #converted sorted tables into xlsx sheets
    makeXlsx(filteredTablesXLSXfile, tableFiles)
    $stderr.puts "DONE"

    $stderr.print "Find features unique to group...\t"
    #identify features that are unique to a meta data group
    identifyFeatuesUniqueToMetaDataGroup(reportSummaryTSVfile, metaDataName)
    $stderr.puts "DONE"
  end

  def identifyFeatuesUniqueToMetaDataGroup(file, metaDataEntryName)
    r = File.open(file, "r")
    header = r.gets.strip
    headerArr = header.split("\t")
    #remove first three entries
    headerArr.delete_at(0)
    headerArr.delete_at(0)
    headerArr.delete_at(0)

    metaValSoloCount = @metaValsArr.length
    metaValCount = @metaComboArr.length
    #metaValCount = @metaListArr.length

    #set up storage for results of uniquely over/underexpressed elements
    overResults = []
    underResults = []
    for pos in (0...metaValSoloCount)
      arr1 = []
      arr2 = []
      overResults << arr1
      underResults << arr2
    end
        

    #then we need to delete the p value headers
    len = headerArr.length / 2
    for i in (0...len)
      headerArr.delete_at(headerArr.length-1)
    end
    #remove quotes and spaces next to dash and save to new array
    pairwiseArr = []
    headerArr.each{ |val|
      newVal = val.gsub(/\"/,"")
      newVal = newVal.gsub(/\ -\ /,"-")
      pairwiseArr.push(newVal)
    }

    lineCount = 0


    r.each{ |line|
      #$stderr.puts line
      spl = line.strip.split("\t")
      #$stderr.puts spl[0]
      #next if spl[0] !~ /89/

      nonZeroCount = 0
      #only output rows that have at least one non-0 value
      for i in (0...metaValCount)
        nonZeroCount += 1 if spl[i+3].to_i != 0
      end

      #if we have a non-zero filled row we can analyze the feature
      if nonZeroCount > 0

        #setup array for comparisons
        oComparisonArray = []
        uComparisonArray = []
        for h in (0...metaValSoloCount)
          oComparisonArray.push(0)
          uComparisonArray.push(0)
        end

        for i in (0...metaValSoloCount)
          #print "\nlooking into: #{@metaValsArr[i]} => "

          metaIndex = @metaValsArr.index(@metaValsArr[i])

          for j in (0..1)
            mval = 0
            if j == 0
              #puts "overexpressed"
              mval = 1
            elsif j == 1
              #puts "underexpressed"
              mval = -1
            end
             
            analyzeArr = [] 
            for k in (0...metaValCount)
              #store value to put into comparisonArray
              evalVal = 0

              metaSpl = pairwiseArr[k].split("-")
              #puts "looking at: #{@metaComboArr[k]} for:::#{@metaValsArr[i]}:::#{metaSpl[0]}::#{metaSpl[1]}"
              #check to see if current meta data val is in first position
              if metaSpl[0].to_s == @metaValsArr[i].to_s
                #puts "found #{@metaValsArr[i]} in first position"
                #puts spl[k+3]
                if mval == 1
                  oComparisonArray[metaIndex] = "1" if spl[k+3].to_i == mval
                elsif mval == -1
                  uComparisonArray[metaIndex] = "1" if spl[k+3].to_i == mval
                end
              #then check if it is in second position
              elsif metaSpl[1].to_s == @metaValsArr[i].to_s
                #puts "found #{@metaValsArr[i]} in 2nd position"
                #puts spl[k+3]
                if mval == 1
                  oComparisonArray[metaIndex] = "1" if (spl[k+3].to_i * -1) == mval
                elsif mval == -1
                  uComparisonArray[metaIndex] = "1" if (spl[k+3].to_i * -1) == mval
                end
              else
                #puts "not in either"
              end
            end
          end
          #exit
          #break
          #puts oComparisonArray
          #puts
          #puts uComparisonArray
          #puts

        end
        #puts oComparisonArray
        #puts
        #puts uComparisonArray
        #puts

        oPos = analyzeExpressionData(oComparisonArray, 1)
        uPos = analyzeExpressionData(uComparisonArray, -1)
   
        overResults[oPos].push(spl[0]) if oPos != -1
        underResults[uPos].push(spl[0]) if uPos != -1

        lineCount += 1
        #exit
        #break if lineCount > 5
      end
    }

    overFile = @outputDirectory + "/#{metaDataEntryName}-uniquelyOverexpressed.tsv"
    underFile = @outputDirectory + "/#{metaDataEntryName}-uniquelyUnderexpressed.tsv"
    xlsxFile = @outputDirectory + "/#{metaDataEntryName}-uniquelyExpressed.xlsx"

    outFiles = []
    outFiles.push(overFile)
    outFiles.push(underFile)

    outputUniquelyExpressed(overFile, overResults)
    outputUniquelyExpressed(underFile, underResults)

    makeXlsx(xlsxFile, outFiles) 
    
    r.close()

  end

  def outputUniquelyExpressed(fileName, arr)
    w = File.open(fileName, "w")

    maxSize = 0

    arr.each_with_index{ |arrInstance, count|
      maxSize = arrInstance.size if arrInstance.size > maxSize
    }

    @metaValsArr.each_with_index{ |metaVal, count|
      w.print "\t" if count > 0
      w.print metaVal
    }
    w.puts
    for pos in (0...maxSize)     
      for metaValPos in (0...@metaValsArr.length)
        w.print "\t" if metaValPos > 0
        outVal = arr[metaValPos][pos]
        if outVal == nil
          w.print " "
        else
          w.print outVal
        end
      end
      w.puts
    end

    w.close()
  end

  def analyzeExpressionData(arr, upDown)
    sum = 0
    pos = -1

    overUnder = ""
    overUnder = "overexpressed" if upDown.to_i == 1
    overUnder = "underexpressed" if upDown.to_i == -1

    arr.each_with_index{ |val, count|
      sum += val.to_i
      pos = count if val.to_i == 1
    } 
    #if we have a sum of 1 then we have a uniquely expressed element
    #if sum == 1
    #  puts "#{overUnder} uniquely for #{@metaValsArr[pos]}"
    #else
    #  puts "----"
    #end

    if sum == 1
      return pos
    else
      return -1
    end

  end


  def makeXlsx(xlsxFileName, fileArray)
    
    #delete xlsx file if it exists otherwise it'll throw error
    `rm -f #{xlsxFileName}`
    #start working with xlsx output
    SimpleXlsx::Serializer.new(xlsxFileName) do |doc|
      fileArray.each{ |file|
        sheetName = File.basename(file.strip)
        doc.add_sheet(sheetName) do |sheet|
          r = File.open(file, "r")
          #output header line
          headerArr = r.gets.strip.split("\t")
          
          #add special cases for poorly R formatted output
          if file =~ /design/ || file =~ /summary\-results/ || file =~ /contrasts/
            headerArr.insert(0, "___")
          end


          sheet.add_row(headerArr)

          #loop through each line and make sure to output floats
          r.each{ |line|
            #substitute spaces with unique string temporarily for proper output
            line.gsub!(/\ /, "xYz0")
            spl = line.strip.split("\t")
            lineArr = []
            for i in (0...spl.size)
              str = spl[i].to_s
              #check to replace our temporary filler string
              if str == "xYz0"
                lineArr.push(" ")
              #check for float
              #if str =~ /[-+]?((\b[0-9]+)?\.)?\b[0-9]+([eE][-+]?[0-9]+)?\b/
              elsif str == nil || str == "" || str == " "
                lineArr.push("x")
              elsif str =~ /[-+]?[0-9]*\.[0-9]+/
                val = convertEval(spl[i].to_f).to_f
                lineArr.push(val)
              #check for string
              elsif str =~ /[a-zA-Z]/
                lineArr.push(spl[i].to_s)
              #check for integer
              #if str =~ /[-+]?\b\d+\b/ 
              elsif str =~ /[-+]?[0-9]+$/
                lineArr.push(spl[i].to_i)
              #otherwise we likely have some other type of string
              else
                lineArr.push(spl[i].to_s)
              end
            end

           #here we can add special cases to not output values that do not
           #  fit certain criteria
           
           #metaValCount = @metaValsArr.length
           metaValCount = @metaComboArr.length
           #metaValCount = @metaListArr.length

           #only output rows that have at least one non-0 value
           if file =~ /Multi-Comparison-Report/
             nonZeroCount = 0
             for i in (0...metaValCount)
               nonZeroCount += 1 if spl[i+3].to_i != 0
             end
             sheet.add_row(lineArr) if nonZeroCount > 0
           else
             sheet.add_row(lineArr)
           end
          }
          #break
          r.close()
        end
      }
    end
  end

  def convertEval(floatVal)
    eVal = 5 
    spl = floatVal.to_s.split("e-")
    if spl.length > 1
      eVal = spl[1].to_i + 2 
    end

    return retVal =  sprintf("%.#{eVal}f", floatVal)
  end

  def processFitGeneListWithTaxonomy(fitFile)
    outFile = fitFile.gsub(/-fitGenes.out$/, "-fitGenes-labelled.tsv")
    w = File.open(outFile, "w")
    r = File.open(fitFile, "r")

    r.each{ |line|
      line.strip!
      w.puts "#{line}\t#{@tax[line.to_s]}"
    }

    w.close()
    r.close()
  end

  def processRawFileIntoTable(rawFile, filter)
    r = File.open(rawFile, "r")

    if filter.to_i == 0
      outFile = rawFile.gsub(/-raw.out$/, "-table.tsv")
    elsif filter.to_i == 1
      outFile = rawFile.gsub(/-raw.out$/, "-filtered_table.tsv")
      @filteredTablesArr.push(outFile)
    end 

    w = File.open(outFile, "w")
    if @opthash["--printTaxonomy"].to_i == 1
      w.puts "ID\tlogFC\tAveExpr\tt\tP.Value\tadj.P.Val\tB\tLabel"
    else
      w.puts "ID\tlogFC\tAveExpr\tt\tP.Value\tadj.P.Val\tB"
    end

    #store values into array for proper outputting 
    valArr = []  

    for i in (0..6)
      val = ""
      for j in (0...@numRows) 
        val = r.gets.strip!
        valArr.push(val)
      end 
    end
    
    for k in (0...@numRows)
      printLine = ""
      printLineBool = 1

      otuID = -1

      for l in (0..6)
        #print "#{valArr[k]}\t#{valArr[k+@numRows*l]}"
        #w.print "\t" if l > 0 

        printLine += "\t" if l > 0
        val = ""
        val = valArr[k+@numRows*l]

        otuID = val if l == 0

        if l == 1 
          val = sprintf('%.2f', val.to_f).to_f
          #printLineBool = 0 if val < @opthash["--minFoldChange"].to_f
          printLineBool = 0 if val.abs < @opthash["--minFoldChange"].to_f
        elsif l == 2 
          val = sprintf('%.2f', val.to_f).to_f
          printLineBool = 0 if val < @opthash["--minAveExp"].to_f
        elsif l == 3
          val = sprintf('%.2f', val.to_f).to_f
        elsif l == 4 
          #val = sprintf('%.8f', val.to_f).to_f
          val = convertEval(val.to_f).to_f
          printLineBool = 0 if val > @opthash["--minPval"].to_f
        elsif l == 5
          #val = sprintf('%.8f', val.to_f).to_f
          val = convertEval(val.to_f).to_f
          printLineBool = 0 if val > @opthash["--minAdjPval"].to_f
        elsif l == 6
          val = sprintf('%.4f', val.to_f).to_f
          printLineBool = 0 if val < @opthash["--minBval"].to_f
        end
        #if we aren't filtering simply append to print line
        printLine += val.to_s
        #w.print val 
      end
      #print taxonomy if it was specified in cmd line args
      printLine += "\t#{@tax[otuID.to_s]}" if @opthash["--printTaxonomy"].to_i == 1

      w.puts printLine if printLineBool == 1 || filter.to_i == 0
    end
  
    r.close()
    w.close()


    return outFile
  end

  def work()
    $stderr.puts @matrixFile if DEBUG == 1
    $stderr.puts @metaFile if DEBUG == 1

    #normalize file and set it to @matrixFile if normalize == 1
    prepareMatrix()
    $stderr.puts "DONE"

    $stderr.puts @matrixFile if DEBUG == 1

    #for each meta data column listed we need to loop
    metaDataVals = @opthash["--metaDataColumns"].split(",")
    metaDataVals.each{ |metaDataVal|
      $stderr.print "Making design file for #{metaDataVal}...\t"
      metaDataCombinationArrays = makeDesign(metaDataVal) 
      $stderr.puts "DONE"
      limma(metaDataVal, metaDataCombinationArrays)
    }
  end

end

#check for proper usage and exit if necessary
settinghash=processArguments()

#initialize input data
limma = Limma.new(settinghash)

#perform alpha diversity pipeline via work function
limma.work()
exit 0

