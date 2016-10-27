#!/usr/bin/env ruby
require 'gsl'
require 'brl/util/util'

# ------------------------------------------------------------------
# Linear Regression on GSL::Vector objects.
# - some reference pages:
#   . explaination for non-statisticians: http://webspace.ship.edu/pgmarr/Geo441/Lectures/Lec%2012%20-%20Intro%20to%20Regression.pdf
#   . comprehensive calculations in C based on values from GSL methods (but simple), with R output confirmation:
#     http://stackoverflow.com/questions/5503733/getting-p-value-for-linear-regression-in-c-gsl-fit-linear-function-from-gsl-li
#   . http://www.perlmonks.org/?node_id=954830
#   . http://rb-gsl.rubyforge.org/
#------------------------------------------------------------------

module BRL ; module Stats
  # Best linear fit of Y = a + bX
  class LinearRegression
    # ------------------------------------------------------------------
    # PROPERTIES
    # ------------------------------------------------------------------
    # The number of X,Y datapoints in the vectors we regressed
    attr_accessor :numDataPoints
    # The intercept "a" in linear model Y = a + bX
    attr_accessor :yIntercept
    # The slope "b" in linear model Y = a + bX
    attr_accessor :slope
    # The Sum of Squares of the Residual [unexplained by regression] error of observed Y values
    attr_accessor :sumSqResiduals
    # The Sum of Squares of the Regression (SS for the error explained by the regression)
    attr_accessor :sumSqRegression
    # The Total Sum of Squares (of observed Y values) = sumSqRegression + sumSqResiduals
    attr_accessor :sumSqTotal
    # The covariance matrix for the regression
    attr_accessor :covarianceMatrix
    # The R^2 of the regression (coefficent of determination)
    attr_accessor :rSq
    # The degrees of freedom for the regression
    attr_accessor :df
    # The Root mean square error the approximation
    attr_accessor :rmsea
    # The F statistic for the regression (for Goodness of Fit test)
    attr_accessor :fStatistic
    # The p-Value for the F-test for Goodness of Fit test
    attr_accessor :fStatisticPvalue
    # The stdev of the y-intercept (sqrt(covarianceMatrix[0]))
    attr_accessor :yInterceptStdev
    # The t-statistic for the test of null hypothesis that y-intercept = 0; alternate hypothesis is we use the best fit y-intercept
    attr_accessor :yInterceptTStatistic
    # The p-value for the t-test of null hypothesis that y-intercept = 0; alternate hypothesis is we use the best fit y-intercept
    attr_accessor :yInterceptPvalue
    # The stdev of the y-intercept (sqrt(covarianceMatrix[2]))
    attr_accessor :slopeStdev
    # The t-statistic for the test of null hypothesis that slope = 0; alternate hypothesis is we use the best fit slope
    attr_accessor :slopeTStatistic
    # The p-value for the t-test of null hypothesis that slope = 0; alternate hypothesis is we use the best fit slope
    attr_accessor :slopePvalue
    # ------------------------------------------------------------------
    # INSTANCE METHODS
    # ------------------------------------------------------------------
    def initialize(gslVectorX, gslVectorY)
      if(gslVectorX.size == gslVectorY.size)
        regression = GSL::Fit::linear(gslVectorX, gslVectorY)
        @numDataPoints = gslVectorX.size
        @yIntercept, @slope = regression[0], regression[1]
        @covarianceMatrix = [ regression[2], regression[3], regression[4] ]
        @sumSqResiduals, @regressionStatus = regression[5], regression[6]
        @sumSqTotal = gslVectorY.tss
        @sumSqRegression = (@sumSqTotal - @sumSqResiduals)
        @rSq = (@sumSqRegression / @sumSqTotal)
        @df = gslVectorY.size - 2
        # F-statistic & p-value for Goodness of Fit test
        @fStatistic = ((@rSq * @df) / (1 - @rSq))
        @fStatisticPvalue = GSL::Cdf::fdist_Q(@fStatistic, 1, @df)
        # p-Value for y-intercept (null hypothesis: yIntercept = 0; alt: use model yIntercept instead)
        @yInterceptStdev = @covarianceMatrix[0]
        @yInterceptStdev = ((@yInterceptStdev != 0.0) ? Math.sqrt(@yInterceptStdev) : (0.0/0.0))
        @yInterceptTStatistic = (@yIntercept / @yInterceptStdev)
        @yInterceptPvalue = (2.0 * GSL::Cdf::tdist_Q(@yInterceptTStatistic.abs, @df))
        # p-Value for slope (null hypothesis: slope = 0; alt: use model slope instead)
        @slopeStdev = @covarianceMatrix[2]
        @slopeStdev = ((@slopeStdev != 0.0) ? Math.sqrt(@slopeStdev) : (0.0/0.0))
        @slopeTStatistic = (@slope / @slopeStdev)
        @slopePvalue = (2.0 * GSL::Cdf::tdist_Q(@slopeTStatistic.abs, @df))
        # Root mean-square error of the approximation (RMSEA)
        @rmsea = @sumSqResiduals / @numDataPoints
        @rmsea = (@rmsea >= 0 ? Math.sqrt(@rmsea) : (0.0/0.0))
      else
        raise "ERROR: gslVectorX and gslVectorY must have the same size to do a regression."
      end
    end

    # Given X, predict Y using the linear model we fit to
    def predictY(xVal)
      return (@yIntercept + (@slope * xVal))
    end

    # Given Y, predict X using the linear mmodel we fit to
    def predictX(yVal)
      return ((yVal - @yIntercept) / @slope)
    end

    # Using the linear model we fit to, calculate the predicted y-values for a vector of X values.
    # - returns a new GSL::Vector containing the predicted Y value for each of your X values.
    def calculatePredictedYs(gslVectorX)
      predictedValsVector = GSL::Vector.alloc(gslVectorX.size)
      gslVectorX.size.times { |ii|
        xVal = gslVectorX[ii]
        # predicted Y from model
        predictedY = (@yIntercept + (@slope * xVal))
        # store
        predictedValsVector[ii] = predictedY
      }
      return predictedValsVector
    end

    # Using the linear model we fit to, calculate the predicted x-values for a vector of Y values.
    # - returns a new GSL::Vector containing the predicted X value for each of your Y values.
    def calculatePredictedXs(gslVectorY)
      predictedValsVector = GSL::Vector.alloc(gslVectorY.size)
      gslVectorY.size.times { |ii|
        yVal = gslVectorY[ii]
        # predicted Y from model
        predictedX = ((yVal - @yIntercept) / @slope)
        # store
        predictedValsVector[ii] = predictedX
      }
      return predictedValsVector
    end

    # Using the linear model we fit to, calculate the residuals for all the X,Y points
    # in gslVectorX and gslVectorY. 
    # - if you already computed all the predicted Y values (via calculatePredictedYs()) BECAUSE YOU *NEED* them,
    #   then you can save time by passing this in so we don't repeat the calculations here
    #   . if you haven't done this for SOME OTHER REASON, then don't bother to provide predictedYVector;
    #     more efficient to do the calculations once here and less memory too!
    # - returns a new GSL::Vector containing the residuals for the observed Y values vs expected Y value from the model
    def calculateResiduals(gslVectorX, gslVectorY, predictedYVector=nil)
      residualsVector = nil
      if(gslVectorX.size == gslVectorY.size)
        # alloc Vector for residuals
        residualsVector = GSL::Vector.alloc(gslVectorY.size)
        # we purposefully duplicate the processing calculation block so
        # we can avoid doing O(gslVectorX.size) tests on predictedYVector
        if(predictedYVector) # then use predictedYVector for getting the predictedY values
          gslVectorY.size.times { |ii|
            xVal = gslVectorX[ii]
            yVal = gslVectorY[ii]
            # predicted Y from model
            predictedY = predictedYVector[ii]
            # compute residual
            residual = (yVal - predictedY)
            residual = residual.abs
            # store
            residualsVector[ii] = residual
          }
        else # no predictedY, calc on the fly
          gslVectorY.size.times { |ii|
            xVal = gslVectorX[ii]
            yVal = gslVectorY[ii]
            # predicted Y from model
            predictedY = (@yIntercept + (@slope * xVal))
            # compute residual
            residual = (yVal - predictedY)
            residual = residual.abs
            # store
            residualsVector[ii] = residual
          }
        end
      else
        raise "ERROR: gslVectorX and gslVectorY must have the same size to do a regression."
      end
      return residualsVector
    end

    # Compute Z-Scores and the corresponding z-test p-values for each residual, testing the null hypothesis that specific
    # residual r is not significantly different from the mean residual (which should be very very close to 0!).
    # Alternative hypothesis is that residual r differs significantly from the mean residual value for the
    # regressed data set.
    #
    # Note that we expect the mean residual to be 0. This is the goal of the least-squares fitting.
    # Note that we assume the residuals are normally distributed. They may NOT be (should you normalize??), e.g. they could show fanning or other weird things.
    # . you can do one check of residual Normality via normalityOfResidualsTTest() below
    #
    # - Provide the residuals vector (e.g. as obtained by calling calculateResiduals(x,y) above)
    # - Returns a Hash with keys: :zScoresVector, :pValuesVector
    def calculateResidualZscoresAndPvalues(residualsVector)
      zscoresVector = GSL::Vector.alloc(residualsVector.size)
      pvaluesVector = GSL::Vector.alloc(residualsVector.size)
      # mean and stdev of the residuals
      mean = residualsVector.mean
      sd = residualsVector.sd
      # compute all zScores and corresponding pValues
      residualsVector.size.times { |ii|
        residual = residualsVector[ii]
        zscoresVector[ii] = zScore = ((residual - mean) / sd)
        pvaluesVector[ii] = (2.0 * GSL::Cdf::gaussian_Q(zScore.abs))
      }
      return { :zScoresVector => zscoresVector, :pValuesVector => pvaluesVector }
    end

    # Normality Test of Residuals
    # - the residuals should be normally distributed around a mean of 0
    #   . we are trying to minimize the sum of squares of the residuals after all
    # - so the normal, standard, and common test of normality is to check this
    #   assumption about the residuals: are they normally distributed around 0?
    # - there are other tests of normality (Shapiro–Wilk) or easier/common RYAN-JOINER
    # - this test should fail to reject the null hypothesis that the mean residual = 0 (i.e. pValue should be ~= 1.0)
    #
    # - Provide the GSL::Vector on which to test normality (e.g. by using calculateResiduals(x,y) above)
    # - Returns a Hash with keys: :tStatistic, :pValue
    def normalityOfResidualsTTest(residualsVector)
      mean = residualsVector.mean
      stdev = residualsVector.sd
      tStatistic = (mean / stdev) * Math.sqrt(residualsVector)
      pValue = (2.0 * (1 - GSL::Cdf::tdist_P((tStatistic < 0.0 ? (-1.0 * tStatistic) : tStatistic), residualsVector.size - 1)))
      return { :tStatistic => tStatistic, :pValue => pValue }
    end
  end # class LinearRegression
end ; end # module BRL ; module Stats
