#!/usr/bin/env ruby
require 'json'
require 'fileutils'
require 'cgi'
require 'brl/util/util'
require 'brl/util/emailer'
require 'gsl'
require 'brl/genboree/rest/apiCaller'
require 'brl/normalize/index_sort'

include GSL
include BRL::Genboree::REST


class EpigenomeComparison

   def initialize(optsHash)
    
        @inputFile      = optsHash['--file']
        @scratch        = optsHash['--scratch']
        @output         = File.expand_path(optsHash['--output'])
        system("mkdir -p #{@output}")
        @removeNoDataRegions        = optsHash['--filter']
        @runName        = CGI.escape(optsHash['--analysis'])
        @quantileNormalized = optsHash['--quantileNormalized']
        @inputFileArray = @inputFile.split(',')
      
   end
   
   ##Main to call either wigdownload or withROI
   def work
      system("mkdir -p #{@scratch}")
      Dir.chdir(@scratch)
      @outputDir = "#{@scratch}/pair-match/#{@runName}"
      system("mkdir -p #{@outputDir}")
      @filewrite = File.open("#{@outputDir}/summary.txt","w+")
      @filewrite.puts "Track\tCorrelation\tSum of Sqaure of Residual\tIntercept\tSlope\tChiSqaure\tRMSEA\tF-Value"
      regression
      @filewrite.close
      system("cp #{@outputDir}/*.lff #{@output}")
      system("cp #{@outputDir}/*.txt #{@output}")
  end
   
    
    ##Linear-regression and other statistical calculations
  def regression      
        for ij in 1...@inputFileArray.size
	   

        file1 = File.open("#{(@inputFileArray[0])}")
        file2 = File.open("#{(@inputFileArray[ij])}")
        file3 = File.open("#{@outputDir}/#{File.basename(@inputFileArray[0]).chomp('?')}_filtered","w+")
        size1 = %x{wc -l #{(@inputFileArray[0])}}.split.first.to_i
        size2 = %x{wc -l #{(@inputFileArray[ij])}}.split.first.to_i
        writeFile = File.open("#{@outputDir}/#{File.basename(@inputFileArray[0])}_#{File.basename(@inputFileArray[ij])}.lff","w+")
        
        @filewrite.print "#{File.basename(@inputFileArray[ij])}\t"
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
           if(@removeNoDataRegions=="true")
               unless((columns1[9].to_f == 0.0 and columns2[9].to_f == 0.0) or (columns1[9].to_i == 4290772992 or columns2[9].to_i == 4290772992))
                  mVec1[track] = columns1[9].to_f
                  mVec2[track] = columns2[9].to_f
                  file3.puts line1
                  track += 1
               end
           else
               mVec1[track] = columns1[9].to_f
               mVec2[track] = columns2[9].to_f
               file3.puts line1
               track += 1
           end
        end
         
         file3.close
         
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
        @filewrite.printf("%6f\t","#{cor}")
          @filewrite.printf("%6f\t","#{lr[5]}")
          @filewrite.printf("%6f\t","#{lr[0]}")
          @filewrite.printf("%6f\t","#{lr[1]}")
         
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
           
           writeFile.puts "#{@lffClass}\t#{column[1]}\t#{@lffType}\t#{@lffSubType}\t#{column[4]}\t#{column[5]}\t#{column[6]}\t#{column[7]}\t#{column[8]}\t#{pValue}\t.\t.\tslope=#{lr[1]}; intercept=#{lr[0]}; predicted=#{predictedValue}; residual=#{residual}; original=#{mVec22[track]}; zScore=#{zScore}; pValue=#{pValue}; minusTenLogTen_pValue=#{minusTenLogTen_pValue}; #{column[12]} "
          track += 1
           }
         rSqaure = 1 - lr[5]/stotal 
        df = mVec11.size - 1
        a = (chiSqaure*chiSqaure)/df-1
        
        @filewrite.printf("%6f\t", chiSqaure)
        if(a>0)
         rmsea = Math.sqrt(((chiSqaure*chiSqaure)/df-1)/(df))
         @filewrite.printf("%6f\t", rmsea)
        else
           @filewrite.printf("NaN\t")
        end
         fValue = rSqaure/(1-rSqaure)
         @filewrite.printf("%6f\n", fValue)
    
      writeFile.close
   
           rescue => err
         $stderr.puts "Deatils: #{err.message}"
         $stderr.puts err.backtrace.join("\n")
        
        end
        end
        
  end
  
 
  
   def EpigenomeComparison.usage(msg='')
          
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
          --filter       | -c => Filter the vectors (true|false)
          --analysis     | -a => Analysis name
          --quantileNormalized |-q => QuantileNormalization (true|false)
          --help         | -h => [Optional flag]. Print help info and exit.
      
       usage:
       
    ruby pairWiseSignalSearch.rb -f '/scratch/wbJob-epigenomeatlassimilaritysearch-1300375415_087078/signal-search/SigSimSrch-2011-03-17-09%3A23%3A20/BI-CD15-H3K27me3-2,
    /scratch/wbJob-epigenomeatlassimilaritysearch-1300375415_087078/signal-search/SigSimSrch-2011-03-17-09%3A23%3A20/BI-CD15-H3K4me3-1'
    -s /scratch -o ~/testQ  -c true -a analysis -q true

      
        ";
            exit;
        end # 
      
      # Process Arguements form the command line input
      def EpigenomeComparison.processArguements()
        # We want to add all the prop_keys as potential command line options
         optsArray = [ ['--file'  ,    '-f', GetoptLong::REQUIRED_ARGUMENT],
                       ['--scratch',   '-s', GetoptLong::REQUIRED_ARGUMENT],
                       ['--output',    '-o', GetoptLong::REQUIRED_ARGUMENT],
                       ['--filter',    '-c', GetoptLong::REQUIRED_ARGUMENT],
                       ['--analysis' , '-a', GetoptLong::REQUIRED_ARGUMENT],
                       ['--quantileNormalized' ,'-q', GetoptLong::REQUIRED_ARGUMENT],
                       ['--help'      ,'-h', GetoptLong::NO_ARGUMENT]
                  ]
      progOpts = GetoptLong.new(*optsArray)
      EpigenomeComparison.usage("USAGE ERROR: some required arguments are missing") unless(progOpts.getMissingOptions().empty?)
      optsHash = progOpts.to_hash
    
      Coverage if(optsHash.empty? or optsHash.key?('--help'));
      return optsHash
      end 


end

optsHash = EpigenomeComparison.processArguements()
performQCUsingFindPeaks = EpigenomeComparison.new(optsHash)
performQCUsingFindPeaks.work()
