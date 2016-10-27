#!/usr/bin/env ruby
require "brl/util/util"
require "brl/script/scriptDriver"
require 'fileutils'
module BRL ; module Script
  class RandomForestPlotter < ScriptDriver
    VERSION = "1.0"
    # INTERFACE provide *specific* command line argument info
    # - Hash of '--longName' arguments to Array of: arg type, one-char arg name, description.
    COMMAND_LINE_ARGS = {
      "--cutoffs" =>  [ :REQUIRED_ARGUMENT, "-c", "List of cutoffs to use" ],
      "--inputDir" =>  [ :REQUIRED_ARGUMENT, "-i", "Input OTU matrix file" ],
      "--outputDir" =>  [ :REQUIRED_ARGUMENT, "-o", "output directory" ],
      "--feature" =>  [ :REQUIRED_ARGUMENT, "-f", "Name of the feature for which plot is being constructed" ]
    }
    # INTERFACE: Provide general program description, author list (you...), and 1+ example usages.
    DESC_AND_EXAMPLES = {
      :description => "Script to plot results of a random forest run",
      :authors      => [ "Sriram Raghuraman (raghuram@bcm.edu)"],
      :examples => [
        "#{File.basename(__FILE__)} -i ./test22.bed.gz -o ./idrTemp/ -n 2",
        "#{File.basename(__FILE__)} --help"
      ]
    }
    
#function reorders lines based on current version of machine learning output
#  *_sortedImportance-gini_trends_3sorted.txt
def reorderReportLines(reportLine)
  reportLine.strip!
  spl = reportLine.split("\t")
  return outLine = [spl[0],spl[1],spl[7],spl[8],spl[9],spl[10],spl[11],spl[2],spl[3],spl[4],spl[5],spl[6],spl[12],spl[13],spl[14],spl[15],spl[21],spl[22],spl[23],spl[24],spl[25],spl[16],spl[17],spl[18],spl[19],spl[20],spl[26],spl[27]].join("\t")
end
    
#http://www.dreamincode.net/code/snippet1371.htm
def calc_median(numbers)
 n = (numbers.length - 1) / 2 # Middle of the array
 n2 = (numbers.length) / 2 # Other middle of the array.
                                       # Used only if amount in array is even
  if numbers.length % 2 == 0 # If number is even
   median = (numbers[n] + numbers[n2]) / 2
  else
   median = numbers[n]
  end
  return median
end

ABUNDANCE = false

def plotResults(feature, cutoffs, inDir, outDir)
  #set ABUNDANCE flag to false if we are doing log transformation
  level = 1
  #create output directory
  FileUtils.mkdir_p outDir
  #set default height and width for output plots
  height = 8
  width = 8

  #tag used to find machine learning full reports
  reportTag = "_sortedImportanceforcombine.gini_trends_3sorted"
  #store machine learning report files
  reportFiles = `ls #{inDir}/RandomForest/*#{reportTag}`.to_a

  #store cut offs into hash
  hCutoffs = Hash.new(0)
  #store meta data names into hash
  hMetaNames = Hash.new(0)

  #the name of the meta data entry that we want on top of the box plots
  #for IBS pain we can use the 'H' value
  topOrderMetaDataName = "H"

  #6-2-11
  #for PTBI study we can use "N"
  topOrderMetaDataName = "N"


  #loop through each report file that we find
cutoffs.each{ |cutoff|
    reportFile = "#{inDir}/RandomForest/#{feature}-#{cutoff}#{reportTag}"
    #store meta data name based on temporary name
    metaName = feature
    #store cut off
    hCutoffs[cutoff] += 1
    #store meta data name
    hMetaNames[metaName] += 1
    #check each report file to see if it's ordered the way that we need for
    #  at least this IBS pain problem, either way we're going to have the
    #  input in the outDir folder
    reportFile.strip!
    `cp #{reportFile} #{outDir}`
  }

  #if we find a 0 transform it to this value
  zeroTransVal = 0.1

  #loop through each cutoff
  hCutoffs.each{ |cutoffVal, cutoffOccurs|
    #
    #  puts cutoffVal
    #   next if cutoffVal !~ /2500/

    #loop through each meta data label
    hMetaNames.each{ |metaName, metaNameOccurs|
      #    next if metaName !~ /MaxPainBinhm/
      #puts
      #open mlReports from outDirectory because we will have to reformat some
      # and we should be consistant with the others
      mlReport = "#{outDir}/#{metaName}-#{cutoffVal}#{reportTag}"
      # usableOTUtable = `ls #{inDir}/*norm#{cutoffVal}-#{metaName}.txt`.strip
      usableOTUtable = "#{inDir}/otu_table_#{cutoffVal}-filtered.forcombine"

      #start writing R script for box plots
      $stderr.puts rFile = "#{outDir}/#{metaName}-#{cutoffVal}.R"
      rWrite = File.open(rFile, "w")

      #read from machine learning report file
      reportRead = File.open(mlReport, "r")
      reportHeader = reportRead.gets

      #bool to store if we have a taxonomy in OTU table
      taxColumnBool = 0

      hOTU = Hash.new(0)

      #loop through OTU table and collect confirmed OTUs in hOTU hash
      puts usableOTUtable
      otuRead = File.open(usableOTUtable, "r")

      sampleArr = otuRead.gets.strip.split("\t")
      #check last entry for Consensus
      taxColumnBool = 1 if sampleArr[sampleArr.length-1] =~ /onsensus/

      #delete first entry label
      sampleArr.delete_at(0)

      #delete last entry if it's consensus lineage (aka taxonomy)
      sampleArr.delete_at(sampleArr.length-1) if taxColumnBool == 1

      #store meta data labels for future lookup
      metaArr = otuRead.gets.strip.split("\t")
      metaArr.delete_at(0)

      #switch this to get order based on report instead of OTU table
      reportHeadSplit = reportHeader.split("\t")
      uniqueVals = []
      reportHeadSplit.each{|rh|
        if(rh =~ /\-min/) then uniqueVals.push(rh.gsub(/\-min/,"")) end
        }
      
      #store max length to adjust width and font size
      maxMetaLen = uniqueVals.map{|uu| uu.length}.max 
      
      
      #store (almost) full names
      hNames = Hash.new(0)

      #store differences between medians between two groups - key = OTU
      hMedianDifference = Hash.new(0)
      #store group0 medians
      hG0medians = Hash.new(0)
      #store group1 medians
      hG1medians = Hash.new(0)

      #store directional change of meta data label (which is UP) - key = OTU
      hDChange = Hash.new(0)

      #store taxonomic depth - key = OTU
      hDepth = Hash.new(0)

      maxTaxLen = 0
      #store confirmed OTUs into hOTU hash
      reportRead.each{ |line|
        #only get confirmed OTUs
        next if line !~ /Confirmed/

        spl = line.split("\t")
        tax = spl[0]
        otuNum = spl[1]
        hOTU[otuNum] = tax

        #store the dicrectional change output from report (26)
        hDChange[otuNum] = spl[-2].gsub(/UP\ in\ /,"")
        #taxSpl = tax.split(";")

        #store max length to better fit plot and labels
        maxTaxLen = tax.length + maxMetaLen

        #hNames[otuNum] = "#{taxSpl[taxSpl.length-1]}-#{otuNum}"
        #if taxSpl.length > 6
        #  hNames[otuNum] = "#{taxSpl[taxSpl.length-1]}-#{otuNum}"
        #  maxTaxLen = tmpLen if tmpLen > maxTaxLen
        #end
        hNames[otuNum] = tax
        #store depth of taxonomic label
        # hDepth[otuNum] = taxSpl.length
        hDepth[otuNum] = tax.length
        #
        #      print taxSpl.length
        #      puts " #{taxSpl[taxSpl.length-1]}-#{otuNum}"
      }
      reportRead.close()

      #produce the yLabelSize based on number of names
      #yLabelSize = 1
      puts yLabelSize = 0.95

      $stderr.debugPuts(__FILE__,__method__,"hNames",hNames.inspect)
      hNamesLen = hNames.length
      if hNamesLen > 23
        if hNamesLen > 35 &&
          yLabelSize = 0.35
          yLabelSize += 0.45 if topOrderMetaDataName == "N"
        else
          yLabelSize = 1 - ((hNamesLen - 22) * 0.05)
          yLabelSize += 0.4 if topOrderMetaDataName == "N"
        end
      end
      puts yLabelSize

      yAxisLabelSizeCode = "cex.axis=#{yLabelSize}"

      #give some buffer room
      maxTaxLen += 10
      rWidth = (maxTaxLen -8) / 2

      #adjust rWidth based on the smaller fonts
      rWidth -= ((1 - yLabelSize) * (rWidth/1.25)).to_i

      #need to have some reasonable size limits for rWidth
      rWidth = 21 if rWidth > 20

      #puts hNamesLen
      #puts yLabelSize
      #puts 1 - ((hNamesLen - 22) * 0.05)
      #puts rWidth

      #save plot into PDF format
      outputPDF = "#{outDir}/#{metaName}-#{cutoffVal}.pdf"
      outputPNG = "#{outDir}/#{metaName}-#{cutoffVal}.PNG"
      rWrite.puts "pdf(file= \"#{outputPDF}\", height=#{height}, width=#{width})"

      #rWrite.puts "par(mar=c(4.5,#{rWidth},0.5,0.5))"
      rWrite.puts "par(xpd=NA,mar=c(4.5,#{rWidth},0.5,0.5))"

      otuCount = 0

      #keep track of which positions in total counts are confirmed OTUs
      validOTUpositions = []

      #store order in which OTUs were collected
      orderOTUarr = []

      #keep track of the size of g0 and g1 for potential legend output
      g0size = 0
      g1size = 0
      
      gsize = []
      groupArr = []
      groupArrCon = []
      
      otuRead.each{ |otuLine|
        otuLine.strip!
        otuCountVals = otuLine.split("\t")
        
        $stderr.debugPuts(__FILE__,__method__,"DEBUG",otuCountVals.inspect)
        otuNum = otuCountVals[0]
        otuCountVals.delete_at(0)

        #delete last entry if it's the taxonomy
        otuCountVals.delete_at(otuCountVals.length-1) if taxColumnBool == 1

        #if we match the OTU number proceed forward with analysis
        if hOTU[otuNum] != 0
          validOTUpositions.push(otuCount)
          orderOTUarr.push(otuNum)

          count = 0
          otuCountVals.each{ |otuval|
            otuval.strip!
            metaLabel = metaArr[count]
            pos = uniqueVals.index(metaLabel)
            if(groupArr[pos].nil?) then groupArr[pos] = [] end
            groupArr[pos].push(otuval)
            count += 1
          }

          #write vector for group0
          
          tmpCount = 0
          groupArr.each_index{|ii|
            rWrite.print "arr-#{ii}-#{otuNum}=c("
            groupArr[ii].each{|g0|
              if g0.to_i == 0
              #setting g0 to 0.1 will make the log transform and divide = -6.0
              g0 = zeroTransVal
              g0Transform = Math::log10(g0.to_f / 100000)
              g0 = g0Transform if ABUNDANCE!=TRUE
              g0 = g0.to_f / 100000 if ABUNDANCE==TRUE
              g0 = "%.4f" % g0
              g0 = 0 if ABUNDANCE==TRUE
              #otherwise we need to divide by 10000 to get percentage and
              #  log transform
            else
              g0Transform = Math::log10(g0.to_f / 100000)
              g0 = g0Transform if ABUNDANCE!=TRUE
              g0 = g0.to_f / 100000 if ABUNDANCE==TRUE
              g0 = "%.4f" % g0
              end
              
            rWrite.print "," if tmpCount > 0
            rWrite.print g0
            if(groupArrCon[ii].nil?) then groupArrCon[ii] = [] end
            groupArrCon[ii].push(g0.to_f)
            tmpCount += 1
          }
          rWrite.puts ")"
            }
          
          groupArrCon.each{|gg| gg.sort!}
          hGmedians = []
          if(hGmedians[otuNum].nil?) then hGmedians[otuNum] = []
          end
          
          groupArrCon.each{|gg| hGmedians[otuNum] << calc_median(gg) }
          
          #store median
          #g0median = calc_median(group0arrCon)
          #g1median = calc_median(group1arrCon)
          ##get the opposite sign of the difference between the two medians
          #hMedianDifference[otuNum] = (g0median - g1median) * -1
          #hG0medians[otuNum] = g0median
          #hG1medians[otuNum] = g1median
          ##store sizes of g0 and g1 arrays for output in legend
          #g0size = group0arr.length
          #g1size = group1arr.length
        end

        otuCount += 1
      }
      #
      #puts otuCount

      #puts "#{g0size}:#{g1size}"

      #this is where we'll determine the order for output of box plots
      otuOrderReverseArr = []
      #keep track of where we switch from one higher group to the other
      higherCountSwitch = 0

      #double sort by which group is higher and then by median difference
      for i in (0..1)
        hMedianDifference.sort{|a,b| a[1]<=>b[1]}.each { |elem|
          higher = hDChange[elem[0]]
          if higher == uniqueVals[i]
            otuOrderReverseArr.push(elem[0])
            higherCountSwitch += 1 if i == 0
          end
        }
      end

      #figure out where to put the dotted line based on where the directional
      # changes switch
      dottedLinePos = (higherCountSwitch * 2) + 0.5
      dottedLineString = "text(-10, #{dottedLinePos}, '"
      for i in (0..999)
        dottedLineString += "."
      end
      dottedLineString += "')"

      #get final filtered count for proper bolding of labels
      finalFilteredCount = 0
      otuOrderReverseArr.each{ |sortedOrderedOTU|
        next if hDepth[sortedOrderedOTU] < 7
        next if hG0medians[sortedOrderedOTU] == -6.0 && hG1medians[sortedOrderedOTU] == -6.0
        finalFilteredCount += 1
      }

      #start writing the names of the OTUs
      rWrite.print "otuFullNames <- c("
      fullNameCount = 0
      #loop though each OTU and print to file - in reverse
      #otuOrderReverseArr.reverse.each{ |sortedOrderedOTU|
      #loop though each OTU and print to file - normal order
      otuOrderReverseArr.each{ |sortedOrderedOTU|
        fullName = hNames[sortedOrderedOTU]
        # puts "#{sortedOrderedOTU}:#{hG0medians[sortedOrderedOTU]}:#{hG1medians[sortedOrderedOTU]}"
        #skip OTU if it has less than a depth of 7 in taxonomic labeling
        #puts "#{sortedOrderedOTU}\t#{hDepth[sortedOrderedOTU]}\t#{hG0medians[sortedOrderedOTU]}\t#{hG1medians[sortedOrderedOTU]}"
        next if hDepth[sortedOrderedOTU] < 7
        next if hG0medians[sortedOrderedOTU] == -6.0 && hG1medians[sortedOrderedOTU] == -6.0
        # puts fullName
        fullName.gsub!(/\"/, "")
        rWrite.print "," if fullNameCount > 0
        #print out full name and meta data name for both groups
        #rWrite.print "\"#{fullName}-#{uniqueVals[0]}\",\"#{fullName}-#{uniqueVals[1]}\""
        #we can also make the text bold for alternating pairs of samples
        if finalFilteredCount % 2 == 0
          if fullNameCount % 2 == 0
            rWrite.print "\"#{fullName}-#{uniqueVals[0]}\",\"#{fullName}-#{uniqueVals[1]}\""
          else
            rWrite.print "expression(bold(\"#{fullName}-#{uniqueVals[0]}\")),expression(bold(\"#{fullName}-#{uniqueVals[1]}\"))"
          end
        else
          if fullNameCount % 2 == 0
            rWrite.print "expression(bold(\"#{fullName}-#{uniqueVals[0]}\")),expression(bold(\"#{fullName}-#{uniqueVals[1]}\"))"
          else
            rWrite.print "\"#{fullName}-#{uniqueVals[0]}\",\"#{fullName}-#{uniqueVals[1]}\""
          end
        end
        #show name (tax) only once per pain
        #rWrite.print "\"#{uniqueVals[0]}\",\"#{fullName}-#{uniqueVals[1]}\""
        fullNameCount += 1
      }
      rWrite.puts ")"

      #print all OTUs vector names
      rWrite.print "boxplot(list("
      validOTUsCount = 0
      #otuOrderReverseArr.reverse.each{ |sortedOrderedOTU|
      #print out OTU vector names in sorted order
      otuOrderReverseArr.each{ |sortedOrderedOTU|
        #skip OTU if it has less than a depth of 7 in taxonomic labeling
        next if hDepth[sortedOrderedOTU] < level.to_i
        next if hG0medians[sortedOrderedOTU] == -6.0 && hG1medians[sortedOrderedOTU] == -6.0

        rWrite.print "," if validOTUsCount > 0
        rWrite.print "x#{sortedOrderedOTU},y#{sortedOrderedOTU}"

        validOTUsCount += 1
      }
      #
      #puts validOTUsCount

      colorCode = ""
      #store colors for alternate coloring scheme
      #color1 = "indianred1"
      color1 = "indianred2"
      #color2 = "cadetblue2"
      color2 = "lightcyan"

      #6-2-11
      if topOrderMetaDataName == "H"
        color1 = "indianred2"
        color2 = "lightcyan"
      elsif topOrderMetaDataName == "N"
        #color1 = "#8b0000"
        color1 = "firebrick"
        color2 = "gray47"
      end

      #set color code based on ordering of meta data groups of which one
      # represents the topOrderMetaDataName (which will be on top)
      colorOrder1 = ""
      colorOrder2 = ""
      sizeOrder1 = 0
      sizeOrder2 = 0
      if uniqueVals[0] =~ /#{topOrderMetaDataName}/
        colorCode = "col=c(\"#{color1}\", \"#{color2}\")"
        colorOrder1 = color2
        colorOrder2 = color1
        sizeOrder1 = g0size
        sizeOrder2 = g1size
      else
        colorCode = "col=c(\"#{color2}\", \"#{color1}\")"
        colorOrder1 = color1
        colorOrder2 = color2
        sizeOrder1 = g1size
        sizeOrder2 = g0size
      end

      #box plot attributes
      #  horizontal=TRUE - make plots horizontal instead of vertical
      #  boxwex = 0.65 - width of box
      #  staplewex = 0.5 - width of staple
      #  outwex = 0.5 - width of outlier
      #  las=1 - print labels horizontally
      #  cex=0.65 - additional way to make outlier circles smaller
      #  xaxt=\"n\" - do not show x axis label (because it will be shrunk
      #    along with the y axis labels
      rWrite.puts "),horizontal=TRUE, pars = list(boxwex = 0.65, staplewex = 0.5, outwex = 0.5, las=1, oma=c(0, 0, 0, 0)), names = otuFullNames, xlab = expression(paste(\"Relative abundance (\",log[10], \")\")), #{colorCode},cex=0.65,#{yAxisLabelSizeCode}, xaxt=\"n\")"
      #create legend data
      #puts "#{uniqueVals[0]}:#{uniqueVals[1]}"
      topLegendVal = ""
      botLegendVal = ""
      if uniqueVals[1] == "H"
        topLegendVal = "H - High (n=#{sizeOrder1})"
      elsif uniqueVals[1] == "HM"
        topLegendVal = "HM - High / Medium (n=#{sizeOrder1})"
      elsif uniqueVals[1] == "HML"
        topLegendVal = "HML - High / Medium / Low (n=#{sizeOrder1})"
      else
        topLegendVal = uniqueVals[1]
      end
      if uniqueVals[0] == "0"
        botLegendVal = "0 - None (n=#{sizeOrder2})"
      elsif uniqueVals[0] == "L0"
        botLegendVal = "L0 - Low / None (n=#{sizeOrder2})"
      elsif uniqueVals[0] == "ML0"
        botLegendVal = "ML0 - Medium / Low / None (n=#{sizeOrder2})"
      else
        botLegendVal = uniqueVals[0]
      end
      #place legend
      rWrite.puts
      #rWrite.puts "legend(-12,-1, c(\"#{topLegendVal}\",\"#{botLegendVal}\"), fill = c(\"#{colorOrder1}\", \"#{colorOrder2}\"))"
      rWrite.puts "legend(par(\"usr\")[1],par(\"usr\")[3], c(\"#{topLegendVal}\",\"#{botLegendVal}\"), fill = c(\"#{colorOrder1}\", \"#{colorOrder2}\"),lty=2,xjust=1.1,yjust=1.1,cex=#{yLabelSize})"
      rWrite.puts
      #re-label the x axis with normal size (because the yAxisLabelSizeCode
      #  shrinks this label too, making it look ackward
      rWrite.puts "axis(1,cex.axis=1)"

      #rWrite.puts dottedLineString
      rWrite.puts "dev.off()"

      rWrite.close()

      # if (fullNameCount >0 )
      #run R script
      `R --vanilla < #{rFile}`

      #convert PDF to PNG
      convertCmd = "convert -density 450 #{outputPDF} #{outputPNG}"
      `#{convertCmd}`

      #delete the PDF file
      `rm -rf #{outputPDF}`
      #end
    }
  }
  
  return(0)
end



    def run()
      begin
        validateAndProcessArgs()
        @exitCode = plotResults(@feature,@cutoffs,@inDir,@outDir)
      rescue => err
        $stderr.puts "Unexpected error while running RandomForestPlotter"
        $stderr.puts "Details: #{err.message}"
        $stderr.puts err.backtrace.join("\n")
        @exitCode = 121
      end
      return @exitCode
    end


    def validateAndProcessArgs
      @feature = @optsHash['--feature']
      @cutoffs = @optsHash['--cutoffs'].split(/,/)
      @inDir = @optsHash['--inputDir']
      @outDir = @optsHash['--outputDir']
    end
  
  end
end ; end # module BRL ; module Script

########################################################################
# MAIN - Provided in the scripts that implement ScriptDriver sub-classes
# - but would look exactly like this ONE LINE:
########################################################################
# IF we are running this file (and not using it as a library), run it:

if($0 and File.exist?($0) and BRL::Script::runningThisFile?($0, __FILE__, true))
  # Argument to main() is your specific class:
  BRL::Script::main(BRL::Script::RandomForestPlotter)
  #
  #fh={"body_site"=>{"T_700095565"=>"Throat", "T_700016994"=>"Throat", "S_700035861"=>"Stool", "T_700101388"=>"Throat", "S_700101600"=>"Stool", "S_700033665"=>"Stool", "T_700101622"=>"Throat", "S_700095850"=>"Stool", "S_700095543"=>"Stool", "T_700095872"=>"Throat"}}
  #BRL::Script::RandomForestDriver.new().runRandomForest("body_site", fh, "/home/raghuram/otu_table.txt","/home/raghuram",[500])
end

