#!/usr/bin/env ruby
require 'json'
require 'fileutils'
require 'cgi'
require 'brl/util/util'
require 'brl/util/emailer'
require 'gsl'
require 'gnuplot'
require 'brl/genboree/rest/apiCaller'
require 'brl/normalize/index_sort'

include GSL
include BRL::Genboree::REST

class PairWiseSimilarity
  def initialize(optsHash)
    @inputFile      = optsHash['--file']
    @scratch        = optsHash['--scratch']
    @outputDir      = optsHash['--output']
    @format         = optsHash['--format']
    @filter         = optsHash['--filter']
    @resolution     = optsHash['--resolution']
    @roiTrackName   = optsHash['--roiTrackName']
    @runName        = CGI.escape(optsHash['--analysis'])
    @normalization = optsHash['--normalization']
    @lffClass       = optsHash["--lffClass"]
    @lffType        = optsHash["--lffType"]
    @lffSubType     = optsHash["--lffSubType"]
    @inputFileArray = @inputFile.split(',')
    @commonFiles = false
    @haveROI = ((@format =~ /LFF/i and @roiTrackName.to_s =~ /\S/) ? true : false)
    @compCount = 1  # Track how many comparisons we do.
  end

  ## Reading files and making vectors
  def readFiles()
    begin
      Dir.chdir(@scratch)
      @outputDir = "#{@scratch}/signal-search/#{@runName}"
      system("mkdir -p #{@outputDir}")
      @filewrite = File.open("#{@outputDir}/summary.txt","w+")
      @inputFileArray[0] = CGI.escape(@inputFileArray[0])
      size1 = %x{wc -l #{@outputDir}/#{(@inputFileArray[0])}}.split.first.to_i

      for i in 1 ...@inputFileArray.size
        @overlappedRegion = ""
        common = ["empty"]
        @inputFileArray[i] = CGI.escape(@inputFileArray[i])
        @inputFileA = CGI.unescape(@inputFileArray[i])
        @inputFileA = @inputFileA.gsub(/_N(\d)+N/,"")
        size2 = %x{wc -l #{@outputDir}/#{(@inputFileArray[i])}}.split.first.to_i

        ##Condition one, if the size of wig is not eqaul
        if(size2 != size1 and @format == "Wig")
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "The sizes of the two wig files are not same. Creating LFF files with common regions...")
          common = findCommonRegioninWig(@inputFileArray[i])
          sizeA = %x{wc -l #{@outputDir}/#{(@inputFileArray[i])}_common}.split.first.to_i
          sizeB = %x{wc -l #{@outputDir}/#{(@inputFileArray[0])}_common}.split.first.to_i
          if(sizeA == sizeB and sizeA.to_i > 0)
            @commonFiles = true
            filterVector(common)
          elsif(sizeA != sizeB )
            $stderr.debugPuts(__FILE__, __method__, "ERROR", "Sizes are not equal for #{@inputFileArray[i]}, query = #{sizeA} and target = #{sizeB} even after selecting common regions")
            @filewrite.write "NaN\t(No data points in regions the tracks have in common)\n"
          else
            $stderr.debugPuts(__FILE__, __method__, "ERROR", "No common region found for #{@inputFileArray[i]}")
            @filewrite.write "NaN\t(No data points in regions the tracks have in common)\n"
          end
        ##Condition two, if the size of Lff is not eqaul
        elsif(size2 != size1 and @format == "Lff")
          $stderr.debugPuts(__FILE__, __method__, "ERROR", "Sizes are not equal for #{@inputFileArray[i]}")
          @filewrite.write "NaN\t(No data points in regions the track have in common)\n"
        else
          filterVector(common)
        end
      end
      @filewrite.close
      system(" gzip #{@outputDir}/finalUploadSummary.lff")
    rescue => err
      $stdout.puts "ERROR:\n #{err}\n\nBacktrace:\n#{err.backtrace.join("\n")}"
    end
  end

  ##Finding common chromosomes between two tracks if they are not equal in size(when there is no ROI)
  def findCommonRegioninWig(fileName)
    file1 = File.open("#{@outputDir}/#{@inputFileArray[0]}.wig")
    file2 = File.open("#{@outputDir}/#{fileName}.wig")
    tempFile1 = File.open("#{@outputDir}/#{@inputFileArray[0]}_common","w+")
    tempFile2 = File.open("#{@outputDir}/#{fileName}_common","w+")

    ##Greping all the chromomosomes
    result1 = %x{grep 'chrom=' #{@outputDir}/#{@inputFileArray[0]}.wig}
    result2 = %x{grep 'chrom=' #{@outputDir}/#{fileName}.wig}

    @chr1 = []
    @chr2 = []
    temp = result1.split(/\n/)
    temp1 = result2.split(/\n/)
    # These hashes will let use know which chr the number of lines are not equal
    @chrLineHash = {}
    @chrLineHash2 = {}

    for i in 0 ...temp.size
      blockHeader = temp[i].split(/\s/)
      blockHeader.each { |avps|
        keyVal = avps.split("=")
        if(keyVal[0].strip == "chrom")
          @chr1[i] = keyVal[1].strip
        end
      }
    end

    for i in 0 ...temp1.size
      blockHeader = temp1[i].split(/\s/)
      blockHeader.each { |avps|
        keyVal = avps.split("=")
        if(keyVal[0].strip == "chrom")
          @chr2[i] = keyVal[1].strip
        end
      }
    end

    ##Intserection of two arrays
    common = @chr1 & @chr2
    @lffClass =""
    @lffType =""
    @lffSubType =""
    @chr =""
    @startPoint = 0
    @endPoint = 0
    ##Making new files for common
    $stderr.debugPuts(__FILE__, __method__, "STATUS", "Creating LFF file for #{@inputFileArray[0]}.wig")
    while( line1 = file1.gets )
      if(line1 =~ /^fixedStep/)
        blockHeader = line1.split(/\s/)
        blockHeader.each { |avps|
          if(avps.split("=")[0].strip == "chrom")
            @chr = avps.split("=")[1].strip
          end
        }
        if(!@chrLineHash.has_key?(@chr) and common.include?(@chr))
          @chrLineHash[@chr] = 0
        end
      end
      if(common.include?(@chr) and line1 !~ /^fixedStep/)
        score = line1.strip
        tempFile1.write("#{@lffClass}\t\t\t\t#{@chr}\t\t\t\t\t#{score}\n")
        @chrLineHash[@chr] += 1
      end
    end
    file1.close
    tempFile1.close
    @startPoint = 0
    @chr = ""
    $stderr.debugPuts(__FILE__, __method__, "STATUS", "Creating LFF file for #{fileName}.wig")
    while( line1 = file2.gets )
      if(line1 =~ /fixedStep/)
        blockHeader = line1.split(/\s/)
        blockHeader.each { |avps|
          if(avps.split("=")[0].strip == "chrom")
            @chr = avps.split("=")[1].strip
          end
          if(!@chrLineHash2.has_key?(@chr) and common.include?(@chr))
            @chrLineHash2[@chr] = 0
          end
        }
      end
      if(common.include?(@chr) and line1 !~ /^fixedStep/)
        score = line1.strip
        tempFile2.write("#{@lffClass}\t\t\t\t#{@chr}\t\t\t\t\t#{score}\n")
        @chrLineHash2[@chr] += 1
      end
    end
    file2.close
    tempFile2.close
    return common
  end

  ## Removing noise from the data by removing "NAN" values and those entry points have zero in same position
  def filterVector(common)
    1.upto(@inputFileArray.lastIndex) { |ij|
      file1 = file2 = size1 = size2 = nil
      if(@commonFiles)
        file1 = File.open("#{@outputDir}/#{(@inputFileArray[0])}_common")
        file2 = File.open("#{@outputDir}/#{(@inputFileArray[ij])}_common")
        size1 = %x{wc -l #{@outputDir}/#{(@inputFileArray[0])}_common}.split.first.to_i
        size2 = %x{wc -l #{@outputDir}/#{(@inputFileArray[ij])}_common}.split.first.to_i
      else
        file1 = File.open("#{@outputDir}/#{(@inputFileArray[0])}")
        file2 = File.open("#{@outputDir}/#{(@inputFileArray[ij])}")
        size1 = %x{wc -l #{@outputDir}/#{(@inputFileArray[0])}}.split.first.to_i
        size2 = %x{wc -l #{@outputDir}/#{(@inputFileArray[ij])}}.split.first.to_i
      end
      file3 = File.open("#{@outputDir}/#{File.basename(@inputFileArray[0]).chomp('?')}_filtered", "w+")
      writeFile = File.open("#{@outputDir}/finalUploadSummary.lff","w+")

      begin
        if(size1 != size2 or size1 == 0)
          @exitCode = $?.exitstatus
          raise "Size of file is different"
        else
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Equal size #{size1}")
        end

        ##Allocating size to vectors and filtering
        mVec1  = GSL::Vector.alloc(size1)
        mVec2  = GSL::Vector.alloc(size1)
        track  = 0
        track1 = 0
        while( line1 = file1.gets and line2 = file2.gets)
          columns1 = line1.chomp.split(/\t/)
          columns2 = line2.chomp.split(/\t/)
          ## Removing noise from the data by removing "NAN" values and those entry points have zero in same position
          if(@filter == "true")
            unless( (columns1[9] == "n/a" or columns2[9] == "n/a") or (columns1[9].to_f == 0.0 and columns2[9].to_f == 0.0) )
              mVec1[track] = columns1[9].to_f
              mVec2[track] = columns2[9].to_f
              file3.puts line1
              track += 1
            end
          else
            if(columns1[9] == "n/a")
              columns1[9] = 0.0
            end
            if(columns2[9] == "n/a")
              columns2[9] = 0.0
            end
            mVec1[track] = columns1[9].to_f
            mVec2[track] = columns2[9].to_f
            file3.puts line1
            track += 1
          end
        end
        file3.close

        mVec11 = GSL::Vector.alloc(track)
        mVec22 = GSL::Vector.alloc(track)
        track.times { |ii|
          mVec11[ii] = mVec1[ii]
          mVec22[ii] = mVec2[ii]
        }

        tempmVec22 = GSL::Vector.alloc(track)
        tempmVec22 = mVec22
        ## flushing out memory
        mVec1 = 0
        mVec2 = 0

        ## Quantile normalization
        if(@normalization != "none")
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Memory before quantile normalizing (#{BRL::Util::MemoryInfo.getMemUsageStr()})")
          indexSorter = IndexSort.new(mVec11, mVec22)
          tempArray = ( @normalization == 'quant' ? indexSorter.quantileNormalization() : indexSorter.gaussianNormalization() )
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Memory after newQuantileNormalized (#{BRL::Util::MemoryInfo.getMemUsageStr()})")
          mVec11 = tempArray[0]
          mVec22 = tempArray[1]
        end

        serror = 0
        ##Calculating linear regression
        chiSquare = 0
        lr  = GSL::Fit::linear(mVec11, mVec22)
        cor = GSL::Stats::correlation(mVec11, mVec22)
        f1 = CGI.unescape(File.basename(@inputFileArray[0])).split(/_N/)[0]
        f2 = CGI.unescape(File.basename(@inputFileArray[ij])).split(/_N/)[0]

        ### Testing version for SVD (Should be removed from here)
        #mat = GSL::Matrix[mVec11.transpose,mVec22.transpose]
        #uFirst, vt, sSecond = mat.SV_decomp
        #sSecond = GSL::Matrix.diagonal(sSecond)
        #fileU = File.open("#{@outputDir}/uFirt.txt","w+")
        #fileS = File.open("#{@outputDir}/sSecond.txt","w+")
        #fileV = File.open("#{@outputDir}/vThird.txt","w+")
        #uFirst.each_row {|row|
        #   fileU.puts row
        #}
        #sSecond.each_row {|row|
        #  fileS.puts row
        #}
        #vt.each_row {|row|
        #  fileV.puts row
        #}
        #fileU.close
        #fileS.close
        #fileV.close

        # Write out track-comparison header and initial regression stats
        @filewrite.puts "\n#{'='*70}"
        @filewrite.puts "Tracks Compared:"
        @filewrite.puts "    #{f1}"
        @filewrite.puts "    #{f2}"
        @filewrite.puts "Dimension for Comparison:"
        if(@haveROI)
          @filewrite.puts "    ROI track #{@roiTrackName.inspect}"
        else
          @filewrite.puts "    #{@resolution}bp windows"
        end
        @filewrite.puts "Settings:"
        @filewrite.puts "    Remove Data-less regions : #{@filter}"
        @filewrite.puts "    Quantile normalize       : #{@quantileNormalized}"
        @filewrite.puts "#{'-'*40}"
        @filewrite.puts "Linear Regression Line ( y = a + bx):"
        @filewrite.printf("    Intercept                      %0.6g\n", lr[0])
        @filewrite.printf("    Slope                          %0.6g\n", lr[1])
        @filewrite.puts "Metrics and Statistics :"
        @filewrite.printf("    Correlation                    %0.6g\n", cor)
        @filewrite.printf("    Sum of Squares of Residuals    %0.6g\n", lr[5])

        ## Calculating z-score and other statistics
        track = 0
        mean = mVec11.mean
        mean2 = mVec22.mean
        stotal = 0
        serror = 0
        mVec22.each_index { |ii|
          value = mVec22[ii]
          diff   = (mean2.to_f - mVec22[ii])
          stotal += ( diff * diff)
        }
        sd = mVec11.sd
        sd2 = mVec22.sd
        chiSquare = 0.0

        ## Calculating residaul, z score and p value for regression
        residualVec = GSL::Vector.alloc(mVec11.size)
        totalRes = 0
        mVec11.each_index { |ii|
          residualVec[ii] = (lr[0] + (lr[1] * mVec11[ii].to_f) - mVec22[ii].to_f)
          totalRes += residualVec[ii]
        }

        meanRes = residualVec.mean
        sdRes = residualVec.sd
        $stderr.puts "STATUS: Mem usage before writing out LFF =>  (#{BRL::Util::MemoryInfo.getMemUsageStr()})"
        file = File.open("#{@outputDir}/#{File.basename(@inputFileArray[0]).chomp('?')}_filtered")
        file.each_line { |line|
          column = line.split(/\t/)
          zScore = (residualVec[track].to_f - meanRes) / sdRes

          ## for two tailed
          pValue = 2*GSL::Cdf::gaussian_Q(zScore.abs)
          predictedValue = (lr[0] + (lr[1] * mVec11[track].to_f))
          residual = (predictedValue.abs - mVec22[track].to_f.abs)
          serror += (residual * residual)
          residual = residual.abs

          chiSquare += (serror / predictedValue)
          if(pValue == 0 or pValue.to_s == "NaN")
            minusTenLogTen_pValue = "out of range"
          else
            minusTenLogTen_pValue = (-10 * Math.log10(pValue))
          end

          pValue1 = roundOf(pValue)
          zScore1 = roundOf(zScore)
          residual1 = roundOf(residual)
          predictedValue1 = roundOf(predictedValue)
          minusTenLogTen_pValue1 = roundOf(minusTenLogTen_pValue)

          writeFile.puts "#{@lffClass}\t#{column[1]}\t#{@lffType}\t#{@lffSubType}\t#{column[4]}\t#{column[5]}\t#{column[6]}\t#{column[7]}\t#{column[8]}\t#{pValue1}\t.\t.\tslope=#{lr[1]}; intercept=#{lr[0]}; predicted=#{predictedValue1}; residual=#{residual1}; original=#{mVec22[track]}; zScore=#{zScore1}; pValue=#{pValue1}; minusTenLogTen_pValue=#{minusTenLogTen_pValue}; #{column[12]} "
          track += 1
        }

        $stderr.puts "STATUS: Mem usage after writing out LFF =>  (#{BRL::Util::MemoryInfo.getMemUsageStr()})"
        rSquare = (1 - (lr[5] / stotal))
        df = (mVec11.size - 1)
        df1minus = (df - 1)
        chiSqSq = (chiSquare * chiSquare)
        aa = (chiSqSq / df1minus)
        fValue = (rSquare / (1 - rSquare))
        if(aa > 0)
          rmsea = Math.sqrt( (chiSqSq / df1minus) / df )
          rmseaStr = ("%0.6g" % rmsea)
        else
          rmseaStr = "NaN"
        end

        # Write out goodness-of-fit stats, etc:
        @filewrite.puts   "    Degree of freedom              #{df}"
        @filewrite.printf("    R-Square                       %0.6g\n", rSquare)
        @filewrite.printf("    F-Value                        %0.6g\n", fValue)
        @filewrite.printf("    Chi-Square                     %0.6g\n", chiSquare)
        @filewrite.printf("    Root Mean Square Error of Approximation    #{rmseaStr}\n")
        @filewrite.printf("    Variance-Covariance Matrix     [%0.6g, %0.6g, %0.6g]\n", lr[2], lr[3], lr[4])
        writeFile.close
      rescue => err
        $stderr.debugPuts(__FILE__, __method__, "ERROR", "Error gathering regression related stats.\nMessage: #{err.message}\nBacktrace:\n#{err.backtrace.join("\n")}")
      end
      @compCount += 1
    }
  end

  def roundOf(a)
    a = a.to_s
    if(a =~/\d+/)
      a=a.to_f
      roundOfValue = (a*10**6).round.to_f/(10.0**6)
    else
      roundOfValue = "NaN"
    end
    return roundOfValue
  end

   def PairWiseSimilarity.usage(msg='')
          unless(msg.empty?)
            puts "\n#{msg}\n"
          end
          puts "

        PROGRAM DESCRIPTION:
           Pairwise epigenome comparison tool
        COMMAND LINE ARGUMENTS:
          --file         | -f => Input files comma sperated, last ROI track(optional)
          --scratch      | -s => Scratch directory
          --output       | -o => Output directory
          --format       | -F => Format of input files (Wig|Lff)
          --filter       | -c => Filter the vectors (true|false)
          --analysis     | -a => Analysis name
          --resolution   | -r => Resolution
          --lffClass     | -l => lffClass
          --lffType      | -L => lffType
          --lffSubType   | -S => lffSubtype
          --quantileNormalized |-q => QuantileNormalization (true|false)
          --help         | -h => [Optional flag]. Print help info and exit.

       usage:



        ";
            exit;
        end #

      # Process Arguements form the command line input
      def PairWiseSimilarity.processArguements()
        # We want to add all the prop_keys as potential command line options
         optsArray = [ ['--file'  ,    '-f', GetoptLong::REQUIRED_ARGUMENT],
                       ['--scratch',   '-s', GetoptLong::REQUIRED_ARGUMENT],
                       ['--output',    '-o', GetoptLong::REQUIRED_ARGUMENT],
                       ['--format',    '-F', GetoptLong::REQUIRED_ARGUMENT],
                       ['--filter',    '-c', GetoptLong::REQUIRED_ARGUMENT],
                       ['--analysis' , '-a', GetoptLong::REQUIRED_ARGUMENT],
                       ['--resolution','-r', GetoptLong::REQUIRED_ARGUMENT],
                       ['--roiTrackName', '-R', GetoptLong::OPTIONAL_ARGUMENT],
                       ['--quantileNormalized' ,'-q', GetoptLong::REQUIRED_ARGUMENT],
                       ['--lffClass' , '-l', GetoptLong::REQUIRED_ARGUMENT],
                       ['--lffType',   '-L', GetoptLong::REQUIRED_ARGUMENT],
                       ['--lffSubType','-S', GetoptLong::REQUIRED_ARGUMENT],
                       ['--help'      ,'-h', GetoptLong::NO_ARGUMENT]
                  ]
      progOpts = GetoptLong.new(*optsArray)
      PairWiseSimilarity.usage("USAGE ERROR: some required arguments are missing") unless(progOpts.getMissingOptions().empty?)
      optsHash = progOpts.to_hash

      Coverage if(optsHash.empty? or optsHash.key?('--help'));
      return optsHash
      end

end

optsHash = PairWiseSimilarity.processArguements()
performQCUsingFindPeaks = PairWiseSimilarity.new(optsHash)
performQCUsingFindPeaks.readFiles()
