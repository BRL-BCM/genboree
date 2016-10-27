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
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/rest/helpers/fileApiUriHelper'
require 'brl/genboree/rest/helpers/projectApiUriHelper'

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
        @runName        = CGI.escape(optsHash['--analysis'])
        @quantileNormalized = optsHash['--quantileNormalized']
        @lffClass       = optsHash["--lffClass"]
        @lffType        = optsHash["--lffType"]
        @lffSubType     = optsHash["--lffSubType"]
        @inputFileArray = @inputFile.split(',')
      
   end
   
    
   ## Reading files and making vectors
  def readFiles()
    begin
        Dir.chdir(@scratch)
        @outputDir = "#{@scratch}/signal-search/#{@runName}"
        system("mkdir -p #{@outputDir}")
        @filewrite = File.open("#{@outputDir}/summary.txt","w+")
        @inputFileArray[0] = CGI.escape(@inputFileArray[0])
        $stdout.puts @inputFileArray[0]
        size1 = %x{wc -l #{@outputDir}/#{(@inputFileArray[0])}}.split.first.to_i
        @mVecOriginal = GSL::Vector.alloc(size1)
        file = File.open("#{@outputDir}/#{(@inputFileArray[0])}")
        track = 0
        while ( line = file.gets )
          columns = line.split(/\t/)
          @mVecOriginal[track] = columns[9].to_f
          track += 1
        end
        file.close()
         
        for i in 1 ...@inputFileArray.size
          @overlappedRegion = ""
          common = ["empty"]
          @inputFileArray[i] = CGI.escape(@inputFileArray[i])
          @inputFileA = CGI.unescape(@inputFileArray[i])
          @inputFileA = @inputFileA.gsub(/_N(\d)+N/,"")
          size2 = %x{wc -l #{@outputDir}/#{(@inputFileArray[i])}}.split.first.to_i
          @mVec1 = @mVecOriginal
          ##Condition one, if the size of wig is not eqaul
          if(size2 != size1 and @format == "Wig")
            common = findCommonRegioninWig(@inputFileArray[i])
            sizeA = %x{wc -l #{@outputDir}/#{(@inputFileArray[i])}_common}.split.first.to_i
            sizeB = %x{wc -l #{@outputDir}/#{(@inputFileArray[0])}_common}.split.first.to_i
            if(sizeA == sizeB and sizeA.to_i > 0)
              @mVec1 = GSL::Vector.alloc(sizeA)
              @mVec2 = GSL::Vector.alloc(sizeA)
              file1 = File.open("#{@outputDir}/#{(@inputFileArray[i])}_common")
              file2 = File.open("#{@outputDir}/#{(@inputFileArray[0])}_common")
              track = 0
              while ( line1 = file1.gets and line2 = file2.gets)
                columns1 = line1.split(/\t/)
                columns2 = line2.split(/\t/)
                @mVec1[track] = columns1[9].to_f
                @mVec2[track] = columns2[9].to_f
                track += 1
              end
              
              file1.close
              file2.close
           #   File.delete("#{@outputDir}/#{(@inputFileArray[i])}_common")
           #   File.delete("#{@outputDir}/#{(@inputFileArray[0])}_common")
              filterVector(common)
              
            elsif(sizeA != sizeB )
              $stdout.puts "error: Sizes are not equal for #{@inputFileArray[i]}, query = #{sizeA} and target = #{sizeB}"
              @filewrite.write "NaN\t(No data points in common region)\n"
            #  File.delete("#{@outputDir}/#{(@inputFileArray[i])}_common")
            #  File.delete("#{@outputDir}/#{(@inputFileArray[0])}_common")
            else
              $stdout.puts "error: No common region found #{@inputFileArray[i]}"
              @filewrite.write "NaN\t(No data points in common region)\n"
            end
             # File.delete("#{@outputDir}/#{(@inputFileArray[i])}.wig")
            
            ##Condition one, if the size of Lff is not eqaul
          elsif (size2 != size1 and @format == "Lff")
              $stdout.puts "error: Sizes are not equal for #{@inputFileArray[i]}"
              @filewrite.write "NaN\t(No data points in common region)\n"
          else
             @mVec2 = GSL::Vector.alloc(size2)
             file = File.open("#{@outputDir}/#{(@inputFileArray[i])}")
             track = 0
             while ( line = file.gets )
               columns = line.split(/\t/)
               @mVec2[track] = columns[9].to_f
               track += 1
            end
            
            file.close()
            filterVector(common)
          end
          
        #  File.delete("#{@outputDir}/#{(@inputFileArray[i])}")
          if(File.exists?("#{@outputDir}/#{(@inputFileArray[i])}.wig"))
         #     File.delete("#{@outputDir}/#{(@inputFileArray[i])}.wig")
          end
        end
        
       
        @filewrite.close
       system(" gzip #{@outputDir}/finalUploadSummary.lff")
        rescue => err
           $stderr.puts "Details: #{err.message}"
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
        
         for i in 0 ...temp.size
          @chr1[i]  =temp[i].split(/chrom=/)[1].split(/span/)[0].strip!
         end
         
         for i in 0 ...temp1.size
          @chr2[i] = temp1[i].split(/chrom=/)[1].split(/span/)[0].strip!
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
         while( line1 = file1.gets )
                 if(line1 =~/variable/)
                         @chr  =line1.split(/chrom=/)[1].split(/span/)[0].strip!	
                 end
                         if(common.include?(@chr) and line1 !~ /variable/)
                         
                                 columns = line1.split(/\s/)
                                 score = columns[1]
                                 @endPoint = columns[0].to_i + @resolution.to_i
                       
                                 tempFile1.write("#{@lffClass}\t\t\t\t\t\t\t\t\t#{score}\n")
                                 @startPoint = @endPoint
                         end
         
         end
         file1.close
         tempFile1.close
         
         @startPoint = 0
         @chr =""
         while( line1 = file2.gets )
                 if(line1 =~/variable/)
                         @chr  =line1.split(/chrom=/)[1].split(/span/)[0].strip!
                 end
                         if(common.include?(@chr) and line1 !~ /variable/)
                                 columns = line1.split(/\s/)
                                 score = columns[1]
                                 @endPoint = columns[0].to_i + @resolution.to_i
                       
                                 tempFile2.write("#{@lffClass}\t\t\t\t\t\t\t\t\t#{score}\n")
                                 @startPoint = @endPoint
                         end
         end     
         file2.close
         tempFile2.close
         return common
    end
    
    
    ## Removin0g noise from the data by removing "NAN" values and those entry points have zero in same position
    def filterVector(common)
       for ij in 1...@inputFileArray.size
	   

        file1 = File.open("#{@outputDir}/#{(@inputFileArray[0])}")
        file2 = File.open("#{@outputDir}/#{(@inputFileArray[ij])}")
        file3 = File.open("#{@outputDir}/#{File.basename(@inputFileArray[0]).chomp('?')}_filtered","w+")
        size1 = %x{wc -l #{@outputDir}/#{(@inputFileArray[0])}}.split.first.to_i
        size2 = %x{wc -l #{@outputDir}/#{(@inputFileArray[ij])}}.split.first.to_i
        writeFile = File.open("#{@outputDir}/finalUploadSummary.lff","w+")
        
     
        begin
            if(size1!=size2 or size1 == 0)
               @exitCode = $?.exitstatus
               raise "Size of file is different"
            else
               $stdout.puts " equal size #{size1}"
            end    
           
        ##Allocating size to vectors and filtering 
        mVec1 = GSL::Vector.alloc(size1)
        mVec2 = GSL::Vector.alloc(size1)
        track =0
        track1 = 0
        while( line1 = file1.gets and line2 = file2.gets)
           columns1 = line1.chomp.split(/\t/)
           columns2 = line2.chomp.split(/\t/)
           ## Removing noise from the data by removing "NAN" values and those entry points have zero in same position
           if(@filter =="true")
               unless((columns1[9].to_f == 0.0 and columns2[9].to_f == 0.0) or (columns1[9].to_i == 4290772992 or columns2[9].to_i == 4290772992))
                  mVec1[track] = columns1[9].to_f
                  mVec2[track] = columns2[9].to_f
                  file3.puts line1
                  track += 1
               end
           else
              if(columns1[9].to_i == 4290772992)
                 columns1[9] = 0.0
              end
              if(columns2[9].to_i == 4290772992)
                 columns2[9] = 0.0
              end
               mVec1[track] = columns1[9].to_f
               mVec2[track] = columns2[9].to_f
               file3.puts line1
               track += 1
           end
        end
         
         file3.close
        if(track <= 6 )
           raise "Cannt proceed further. Only #{track} data points to make model"
        end
        
        mVec11 = GSL::Vector.alloc(track)
        mVec22 = GSL::Vector.alloc(track)
        for i in 0...track
           mVec11[i] = mVec1[i]
           mVec22[i] = mVec2[i]
        end
        
        tempmVec22 = GSL::Vector.alloc(track)
        tempmVec22 = mVec22
       ## flushing out memory
       mVec1 = 0
       mVec2 = 0
      
       ## Quantile normalization
        if( @quantileNormalized == "true")
           $stdout.puts "Normalizing"
         temp = IndexSort.new(mVec11,mVec22)
         tempArray = []
         temp.sort_index()
         tempArray =  temp.newQuantileNormalized()
         mVec11 = tempArray[0]
         mVec22 = tempArray[1]
        end
        
        serror = 0
        ##Calculating linear regression\
        chiSqaure = 0
        lr  = GSL::Fit::linear(mVec11,mVec22)
        cor = GSL::Stats::correlation(mVec11,mVec22)
        f1 = CGI.unescape(File.basename(@inputFileArray[0])).split(/_N/)[0]
        f2 = CGI.unescape(File.basename(@inputFileArray[ij])).split(/_N/)[0]
        
     
        
      
        
        @filewrite.puts "Input Tracks:"
        @filewrite.puts "   #{f1}"
        @filewrite.puts "   #{f2}"
        @filewrite.puts "Settings:"
        @filewrite.puts "   removeNoDataRegions  : #{@filter}"
        @filewrite.puts "   quantileNormalized   : #{@quantileNormalized}"
        @filewrite.puts "\n-----------------------\n"
        
        @filewrite.puts "Linear Regression Line ( y = a + bx):"
        @filewrite.printf("   Intercept \t%6f\n","#{lr[0]}")
        @filewrite.printf("   Slope \t%6f\n","#{lr[1]}")
        @filewrite.puts "Metrics and Statistics :"
        @filewrite.printf("   Correlation\t%6f\n","#{cor}")
        @filewrite.printf("   Sum of Sqaures of residual\t%6f\n","#{lr[5]}")
         
        ## Calculating z-score and other statistics 
        track = 0
        mean = mVec11.mean
        mean2 = mVec22.mean
        stotal = 0
        serror = 0
        for ii in 0 ...mVec22.size
           stotal  = stotal + (mean2.to_f - mVec22[ii])*(mean2.to_f - mVec22[ii])
        end
        sd = mVec11.sd
        sd2 = mVec22.sd
        chiSqaure = 0.0
         
         
        ## Calculating residaul, z score and p value for regression
        residualVec = GSL::Vector.alloc(mVec11.size)
        totalRes = 0
        for i in 0...mVec11.size
           residualVec[i] = lr[0]+lr[1]*mVec11[i].to_f - mVec22[i].to_f
           totalRes = totalRes + residualVec[i]
        end
      
        
        meanRes = residualVec.mean
        sdRes = residualVec.sd
      
        file = File.open("#{@outputDir}/#{File.basename(@inputFileArray[0]).chomp('?')}_filtered")
        file.each_line{|line|
            
          column = line.split(/\t/)
          zScore = (residualVec[track].to_f - meanRes)/sdRes
          
          ## for two tailed
          pValue = 2*GSL::Cdf::gaussian_Q(zScore.abs)
          predictedValue = lr[0]+lr[1]*mVec11[track].to_f
          residual = predictedValue.abs - mVec22[track].to_f.abs
          serror = serror + residual*residual
          residual = residual.abs
           
           chiSqaure = chiSqaure + residual*residual/predictedValue
           if(pValue == 0 or pValue.to_s == "NaN")
              minusTenLogTen_pValue = "out of range"
           else
            minusTenLogTen_pValue = -10*Math.log10(pValue)
           end
           pValue1= roundOf(pValue)
           zScore1 = roundOf(zScore)
           residual1 = roundOf(residual)
           predictedValue1 = roundOf(predictedValue)
           minusTenLogTen_pValue1 = roundOf(minusTenLogTen_pValue)
           
           writeFile.puts "#{@lffClass}\t#{column[1]}\t#{@lffType}\t#{@lffSubType}\t#{column[4]}\t#{column[5]}\t#{column[6]}\t#{column[7]}\t#{column[8]}\t#{pValue1}\t.\t.\tslope=#{lr[1]}; intercept=#{lr[0]}; predicted=#{predictedValue1}; residual=#{residual1}; original=#{mVec22[track]}; zScore=#{zScore1}; pValue=#{pValue1}; minusTenLogTen_pValue=#{minusTenLogTen_pValue}; #{column[12]} "
          track += 1
           }
        rSqaure = 1 - lr[5]/stotal 
        df = mVec11.size - 1
        a = (chiSqaure*chiSqaure)/df-1
        
        fValue = rSqaure/(1-rSqaure)
        @filewrite.printf("   R-Square \t%6f\n", "#{rSqaure}")
        fValue = rSqaure/(1-rSqaure)
        
        @filewrite.printf("   F-Value\t%6f\n", fValue)
        @filewrite.printf("   Chi-Square\t%6f\n", chiSqaure)
        df = mVec11.size - 1
        $stdout.puts "df #{df}"
        a = (chiSqaure*chiSqaure)/df-1
        if(a>0)
         rmsea = Math.sqrt(((chiSqaure*chiSqaure)/df-1)/(df))
         @filewrite.printf("   Root Mean Sqaure Error of Approximation\t%6f\n", rmsea)
        else
         @filewrite.printf("   Root Mean Sqaure Error of Approximation\tNaN\n")
        end
        
        @filewrite.puts "   Degree of freedom\t #{df}"
        @filewrite.puts "   Variance-covariance matrix \t[#{lr[2]},#{lr[3]},#{lr[4]}]"
        writeFile.close
        rescue => err
         $stderr.puts "Details: #{err.message}"
         $stderr.puts err.backtrace.join("\n")
        end
      end
       
       
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
