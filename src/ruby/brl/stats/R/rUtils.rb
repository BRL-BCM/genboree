#!/usr/bin/env ruby
require 'stringio'
require 'brl/util/util'
require 'brl/stats/R/rinruby'

module BRL ; module Stats ; module R
  # Exception class specifically raised when we notice R is reporting errors/problems
  class R_Exception < StandardError ; end

  # Class containing a set methods for doing some basic calculations using R.
  # @note By default this class creates a new R sub-process to talk to and feed with R code.
  #   When you're ALL done using the methods of this class, you should call {#shutdown} so that
  #   sub-process can be destroyed and the system resources--sometimes significant--freed.
  class RUtils
    # @return [Boolean] indicating whether or not this instance was told to create a new,
    #   independant R sub-process (@true@) or told to reuse the automatic global R process shared by
    #   all code in this process (@false@)
    attr_reader :createNewREngine
    # @return [BRL::Stats::R::RinRuby] either a new {RinRuby} instance or the global shared one (i.e. @::R@)
    attr_reader :rEngine

    # CONSTRUCTOR.
    # @param [Boolean] createNewREngine Indicates whether to create a new, independent R engine or use the
    #   global shared R engine.
    def initialize(createNewREngine=true)
      @createNewREngine = createNewREngine
      if(@createNewREngine)  # then we want a new, independent R to use
        @rEngine = BRL::Stats::R::RinRuby.new()
      else # Re-use the global R created when brl/stats/R/rinruby.rb was FIRST required
        @rEngine = ::R
      end
    end

    # Shutdown, if appropriate, the R engine in use. Always call this to free R resources when done! Don't worry it won't
    #   shutdown the global shared R process.
    # @return [Boolean] indicating if an R engine whas shutdown or not. Typically @true@ if using a new, independant R engine.
    def shutdown()
      retVal = false
      if(@createNewREngine)
        retVal = self.class.shutdown(@rEngine)
      end
      return retVal
    end

    # Shutdown the provided R engine. Used internally by {#shutdown}.
    # @example Can be used to shutdown the shared global R engine as well if called like this:
    #   BRL::Stats::R::RUtils.shutdown(::R)
    # @param [BRL::Stats::R::RinRuby] rEngine The {RinRuby} instance to shutdown.
    # @return [Boolean] indicating whether or not the @rEngine@ was shutdown.
    def self.shutdown(rEngine)
      retVal = false
      if(rEngine.is_a?(BRL::Stats::R::RinRuby))
        rEngine.quit rescue false
        rEngine = nil
        retVal = true
      end
      return retVal
    end

    # Compute the value from the hypergeometric distribution function using R's phyper() function.
    # i.e. the probability value (p-value for certain tests).
    # http://stat.ethz.ch/R-manual/R-patched/library/stats/html/Hypergeometric.html
    # @param [Fixnum] numSubpop1Obs The number of samples from sub-population 1 that were observed. ("white balls drawn without replacement")
    # @param [Fixnum] totalNumSubpop1 The total number of items in the whole population who are in sub-population 1 ("total white balls in urn")
    # @param [Fixnum] totalNumNonSubpop1 The total number of items in the whole population who are NOT in sub-population 1 ("total black balls in urn")
    # @param [Fixnum] numSamples The number of samples taken of the population ("number of balls drawn from urn")
    # @param [Boolean] lowerTail Indicating whether to use lower tail P[X<=x] or the inverse probability upper tail P[X>x]. Default is same as R's: @true@.
    # @param [Boolean] log Indicating whether to return the probability as log(p). Default is same as R's: @false@.
    # @param [Float] The hypergeometric distribution function value for the provided arguments.
    # @raise [ArgumentError] When any of the count/number arguments is not a positive integer.
    # @raise [BRL::Stats::R:R_Exception] When the R engine indicates an error was generated in R when trying to
    #   compute the correlation. Likely due to bad input from the files, etc.
    def phyper(numSubpop1Obs, totalNumSubpop1, totalNumNonSubpop1, numSamples, lowerTail=true, log=false)
      result = err = nil
      # Ensure we have count args as integers
      numSubpop1Obs, totalNumSubpop1, totalNumNonSubpop1, numSamples =
        numSubpop1Obs.to_i, totalNumSubpop1.to_i, totalNumNonSubpop1.to_i, numSamples.to_i
      # Check sanity of inputs, to catch problems in Ruby BEFORE R starts complaining
      if(numSubpop1Obs >= 0 and totalNumSubpop1 >= 0 and totalNumNonSubpop1 >= 0 and numSamples >= 0)
        @rEngine.qq = numSubpop1Obs
        @rEngine.mm = totalNumSubpop1
        @rEngine.nn = totalNumNonSubpop1
        @rEngine.kk = numSamples
        rOk = @rEngine.eval <<-EOR
          distFunVal <- phyper(qq, mm, nn, kk, lower.tail=#{lowerTail ? "TRUE" : "FALSE"}, log.p=#{log ? "TRUE" : "FALSE"})
          valOk  <- as.integer( exists("distFunVal") )
        EOR
        if(!rOk or @rEngine.errorReported)
          raise R_Exception, "ERROR: R encountered a problem using the input args to compute a value from the hypergeometric distribution function.\n  - args: qq=#{numSubpop1Obs.inspect} ; mm=#{totalNumSubpop1.inspect} ; nn=#{totalNumNonSubpop1.inspect} ; kk=#{numSamples.inspect} ; lowerTail? #{lowerTail.inspect} ; log? #{log.inspect}\n  - eval() ok? #{rOk.inspect}\n  - R indicated an error? #{@rEngine.errorReported}#{ "\n  - Error message from R:\n\n#{@rEngine.errorMsg}" if(@rEngine.errorReported and @rEngine.errorMsg)}\n"
        elsif(@rEngine.valOk != 1)
          raise R_Exception, "ERROR: R encountered a problem computing your actual hypergeometric distribution function, but did not formally indicate an error. The 'distFunVal' R variable appears not to exist whereas it should following a successfull distribution function (phyper) call."
        else # seems fine, get correlation
          result = @rEngine.distFunVal
        end
      else # um, negative counts or something??
        raise ArgumentError, "ERROR: One or more of the arguments to the hypergeometric distribution function are NEGATIVE? That makes no sense. R's phyper() will return NaN and complain with error messages.\n  - args: qq=#{numSubpop1Obs.inspect} ; mm=#{totalNumSubpop1.inspect} ; nn=#{totalNumNonSubpop1.inspect} ; #{numSamples.inspect}"
      end
      return result
    end

    # Compute the correlation between the numbers in a specific column of two compatible tab-delimited files.
    # @note The two files must have the same number of columns, have the same column header names [if any], and
    #   must have the same number of rows [so the numeric vectors have the same sense and can get a meaningful correlation].
    # @note Be careful regarding comment lines and indicating the data column using a column name {String}. If your header
    #   is in a comment line [common], R will skip the comment and thus won't see the column names; but the {Symbol} based
    #   column index approach would work perfectly. If you indicate that comments should NOT be skipped in order to use
    #   your column names in the comment line, you better not have ANY other comment lines; R will see & try to use them too!
    #   Seriously, nice commenting with @#@ and the column-index {Symbol} approach is easy and safe and clean...
    # @param [String] Path to the 1st file
    # @param [String] Path to the 2nd file
    # @param [Symbol, String] dataColName *If* the two files have *no header*, provide a {Symbol} in R's column index form @:Vx@ where @x@
    #   is the column number (starting at 1) where the numbers to correlate can be found. e.g. @:V4@ *Else if* the
    #   two files have a header row, provide a {String} with the name of the column containing the numbers to correlate.
    #   e.g. @Score@. Default is @:V1@ for a headerless file with numbers in the 1st column (and perhaps no other columns).
    # @param [String] method The correlation method to use. Must correspond to one of the method supported by R's @cor()@
    #   function. Currently: @:pearson@, @:spearman@, @:kendall@ (warning, the latter is VERY SLOW)
    # @param [String] commentChar Specify the character that indicates comment lines that R will skip entirely, or @nil@
    #   to turn off skipping comment lines. Note: if your header line starts with @#@ AND you are using a named column
    #   in @dataColName@ (i.e. you are providing the column name as a {String}) rather than the {Symbol} column-index approach
    #   _you must provide @commentChar=nil@ or R will not see your column headers and will not get your data._ Of course, then
    #   R will try to interpret *all* the comment lines, which could cause other problems. When you have comment lines, including
    #   the column headers, do consider just using the {Symbol} column index approach for @dataColName@ instead...it will work nicely.
    #   Default is R's default: @#@.
    # @return [Float] The correlation between the numbers in the two files.
    # @raise [ArgumentError] When either of the files doesn't exist, isn't readable, or isn't a file; or if @dataColumn@
    #   is a {Symbol} but not in the form @:Vx@ where @x@ is an integer.
    # @raise [BRL::Stats::R:R_Exception] When the R engine indicates an error was generated in R when trying to
    #   compute the correlation. Likely due to bad input from the files, etc.
    def fileCorrelation(path1, path2, dataColName=:V1, method=:pearson, commentChar="#")
      result = err = nil
      path1, path2 = File.expand_path(path1), File.expand_path(path2)
      if(File.readable?(path1) and File.file?(path2))
        if(File.readable?(path2) and File.file?(path2))
          col = dataColName.to_s
          if( (dataColName.is_a?(Symbol) and col =~ /^V\d/) or dataColName.is_a?(String) )
            hdr = (dataColName.is_a?(Symbol) ? "FALSE" : "TRUE")
            col = dataColName.to_s
            rOk = @rEngine.eval <<-EOR
              xx      <- read.table("#{path1}", header=#{hdr}, sep="\\t", comment.char="#{commentChar}")
              yy      <- read.table("#{path2}", header=#{hdr}, sep="\\t", comment.char="#{commentChar}")
              corr    <- cor(xx[["#{col}"]], yy[["#{col}"]], use="everything", method="#{method}")
              corrOk  <- as.integer( exists("corr") )
            EOR
            if(!rOk or @rEngine.errorReported)
              raise R_Exception, "ERROR: R encountered a problem using the args to compute a correlation. Do both files have the same column name for the data column (or both have no column headers)? Do both files have the same number of data values? Have you provided a valid column name?\n  - eval() ok? #{rOk.inspect}\n  - R indicated an error? #{@rEngine.errorReported}#{ "\n  - Error message from R:\n\n#{@rEngine.errorMsg}" if(@rEngine.errorReported and @rEngine.errorMsg)}\n"
            elsif(@rEngine.corrOk != 1)
              raise R_Exception, "ERROR: R encountered a problem computing your actual correlation, but did not formally indicate an error. The 'corr' R variable appears not to exist whereas it should following a successfull correlation call."
            else # seems fine, get correlation
              result = @rEngine.corr
            end
          else  # Not supported dataColName,hasHeaderRow combination
            raise ArgumentError, "ERROR: Either dataColName arg is a Symbol with the R-auto-assigned colname with the data (i.e. :V1, :V2, etc) OR dataColName is a String with the name of the data column in your files [obviously, both files must have a header row and they both must have that column in this case]."
          end
        else
          raise ArgumentError, "ERROR: The following file is either doesn't exist, isn't readable, or is not a file: #{path2.inspect}"
        end
      else
        raise ArgumentError, "ERROR: The following file is either doesn't exist, isn't readable, or is not a file: #{path1.inspect}"
      end
      return result
    end
  end # class RUtils
end ; end ; end # module BRL ; module Stats ; module R
