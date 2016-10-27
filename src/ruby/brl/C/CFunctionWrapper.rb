#!/usr/bin/env ruby

module BRL #:nodoc:
module C #:nodoc:

# A class for wrapping entire C functions as constants.
# To be used with RubyInline when building up a C source to be compiled.
class CFunctionWrapper
  ##################
  # Constants
  ##################
  MIN_VALUE_BY_TYPE = {
    "float" => "-FLT_MAX",
    "gfloat" => "-FLT_MAX",
    "double" => "-DBL_MAX",
    "gdouble" => "-DBL_MAX",
    "char" => "CHAR_MIN",
    "int" => "INT_MIN",
    "long" => "LONG_MIN",
    "unsigned char" => "UCHAR_MIN",
    "unsigned int" => "UINT_MIN",
    "unsigned long" => "ULONG_MIN",
    "gint8" => "G_MININT8",
    "guint8" => "0",
    "gint16" => "G_MININT16",
    "guint16" => "0",
    "gint32" => "G_MININT32",
    "guint32" => "0",
    "gint64" => "G_MININT64",
    "guint64" => "0"
  }

  MAX_VALUE_BY_TYPE = {
    "float" => "FLT_MAX",
    "gfloat" => "FLT_MAX",
    "double" => "DBL_MAX",
    "gdouble" => "DBL_MAX",
    "char" => "CHAR_MAX",
    "int" => "INT_MAX",
    "long" => "LONG_MAX",
    "unsigned char" => "UCHAR_MAX",
    "unsigned int" => "UINT_MAX",
    "unsigned long" => "ULONG_MAX",
    "gint8" => "G_MAXINT8",
    "guint8" => "G_MAXUINT8",
    "gint16" => "G_MAXINT16",
    "guint16" => "G_MAXUINT16",
    "gint32" => "G_MAXINT32",
    "guint32" => "G_MAXUINT32",
    "gint64" => "G_MAXINT64",
    "guint64" => "G_MAXUINT64"
  }
  #------------------------------------------------------------------
  # COMPILATION & HEADER INFO
  #------------------------------------------------------------------
  BASE_COMPILE_FLAGS = '--std=c99'
  DEBUG_COMPILE_FLAGS = ' -g '
  MATHLIB_COMPILE_FLAGS = '-lm'
  ZLIB_COMPILE_FLAGS = '-lz'
  GLIB_COMPILE_FLAGS = `pkg-config --cflags glib-2.0`.chomp
  LIMITS_HEADER_INCLUDE = '<limits.h>'
  MATH_HEADER_INCLUDE = '<math.h>'
  GLIB_HEADER_INCLUDE = '<glib.h>'
  RUBY_HEADER_INCLUDE = '<ruby.h>'
  ZLIB_HEADER_INCLUDE = '<zlib.h>'
  ASSERT_HEADER_INCLUDE = '<assert.h>'

  #------------------------------------------------------------------
  # COMPARISON FUNCTIONS - for qsort or bsearch
  #------------------------------------------------------------------
  # Compare 2 args. Ruby will replace {TYPE} and {CAPTYPE} in here to create
  # a type-specific comparison function. Should be good for any simple type.
  COMPARE_TEMPLATE = <<-EOS
    int compare{CAPTYPE}(const void * x, const void * y)
    {
      return (*(const {TYPE} *)x - *(const {TYPE} *)y) ;
    }
  EOS

  #------------------------------------------------------------------
  # DESCRIPTIVE STATS FUNCTIONS - compute descritpive statistics on numbers in an array
  #------------------------------------------------------------------
  # Calc median of an array of simple type (placeholder: {TYPE}).
  # Ruby will replace {TYPE} and {CAPTYPE} in here to create
  # a type-specific median function. Should be good for any simple type.
  MEDIAN_TEMPLATE = <<-EOS
    {TYPE} calcMedianFor{CAPTYPE}( {TYPE} * array, unsigned long len )
    {
      {TYPE} median ;
      qsort( (void *)array, (size_t)len, sizeof({TYPE}), compare{CAPTYPE}) ;
      if(len % 2 == 0)
      {
        median = ((array[(len / 2) - 1]) + (array[len / 2])) / 2 ;
      }
      else
      {
        median = array[((len + 1) / 2) - 1] ;
      }
      return median ;
    }
  EOS

  # Calc mean of an array of simple type (placeholder: {TYPE})
  # Ruby will replace {TYPE} and {CAPTYPE} in here to create
  # a type-specific mean function. Should be good for any simple type.
  MEAN_TEMPLATE = <<-EOS
    {TYPE} calcMeanFor{CAPTYPE}( {TYPE} * array, unsigned long len )
    {
      {TYPE} mean = ({TYPE})0 ;
      for(int ii=0; ii<len; ii++)
      {
        mean += array[ii] ;
      }
      return ({TYPE})(mean / len) ;
    }
  EOS

  # Calc sum of an array of simple type (placeholder: {TYPE})
  # Ruby will replace {TYPE} and {CAPTYPE} in here to create
  # a type-specific sum function. Should be good for any simple type.
  SUM_TEMPLATE = <<-EOS
    {TYPE} calcSumFor{CAPTYPE}( {TYPE} * array, unsigned long len )
    {
      {TYPE} sum = ({TYPE})0 ;
      for(int ii=0; ii<len; ii++)
      {
        sum += array[ii] ;
      }
      return sum ;
    }
  EOS

  # Calc standard deviation of an array of simple type (placeholder: {TYPE})
  # Ruby will replace {TYPE} and {CAPTYPE} in here to create
  # a type-specific sum function. Should be good for any simple type.
  STDEV_TEMPLATE = <<-EOS
    {TYPE} calcStdevFor{CAPTYPE}( {TYPE} * array, unsigned long len)
    {
      {TYPE} mean = ({TYPE})0 ;
      {TYPE} sumOfSqs = ({TYPE})0 ;
      // First, get mean
      for(int ii=0; ii<len; ii++)
      {
        mean += array[ii] ;
      }
      mean /= len ;
      // Second, sum of Squares
      for(int ii=0; ii<len; ii++)
      {
        {TYPE} diff = (array[ii] - mean) ;
        sumOfSqs += (diff * diff) ;
      }
      // Return stdev
      return ({TYPE})(sqrt(sumOfSqs / len)) ;
    }
  EOS

  # Calc max of an array of simple type (placeholder: {TYPE})
  # Ruby will replace {TYPE} and {CAPTYPE} and {MIN_VALUE} in here to create
  # a type-specific max function. Should be good for any simple type.
  MAX_TEMPLATE = <<-EOS
    {TYPE} calcMaxFor{CAPTYPE}( {TYPE} * array, unsigned long len )
    {
      {TYPE} max = {MIN_VALUE} ;
      for(int ii=0; ii<len; ii++)
      {
        if(array[ii] > max)
        {
          max = array[ii] ;
        }
      }
      return max ;
    }
  EOS

  # Calc min of an array of simple type (placeholder: {TYPE})
  # Ruby will replace {TYPE} and {CAPTYPE} and {MAX_VALUE} in here to create
  # a type-specific min function. Should be good for any simple type.
  MIN_TEMPLATE = <<-EOS
    {TYPE} calcMinFor{CAPTYPE}( {TYPE} * array, unsigned long len )
    {
      {TYPE} min = {MAX_VALUE} ;
      for(int ii=0; ii<len; ii++)
      {
        if(array[ii] < min)
        {
          min = array[ii] ;
        }
      }
      return min ;
    }
  EOS

  #------------------------------------------------------------------
  # Helper Class Methods
  #------------------------------------------------------------------
  # Make C comparison functions code for one or more simple C types.
  # - For glib types (gfloat, guint8, etc), will require include of <glib.h> and
  #   compilation flags of 'pkg-config --cflags glib-2.0'
  def self.comparisonFunctions(*types)
    retVal = ''
    types.each { |type|
      retVal << COMPARE_TEMPLATE.gsub(/\{TYPE\}/, type).gsub(/\{CAPTYPE\}/, type.capitalize)
    }
    return retVal
  end

  # Make C median functions code for one or more simple C types.
  # - ASSUMES that appropriate type-specific comparison function will available to the source
  #   (i.e. already added or added together with this function; the appropriate comparision function
  #   can be opbtained via CFunctionWrapper.makeComparisonFunction("float") or similar.
  # - For glib types (gfloat, guint8, etc), will require include of <glib.h> and
  #   compilation flags of 'pkg-config --cflags glib-2.0'
  def self.medianFunctions(*types)
    retVal = ''
    types.each { |type|
      retVal << MEDIAN_TEMPLATE.gsub(/\{TYPE\}/, type).gsub(/\{CAPTYPE\}/, type.capitalize)
    }
    return retVal
  end

  # Make C mean functions code for one or more simple C types.
  # - Check that the MIN_VALUE_BY_TYPE hash in this class has keys for all your types.
  # - For glib types (gfloat, guint8, etc), will require include of <glib.h> and
  #   compilation flags of 'pkg-config --cflags glib-2.0'
  def self.meanFunctions(*types)
    retVal = ''
    types.each { |type|
      retVal << MEAN_TEMPLATE.gsub(/\{TYPE\}/, type).gsub(/\{CAPTYPE\}/, type.capitalize)
    }
    return retVal
  end

  # Make C stdev functions code for one or more simple C types.
  # - Requires inclue of <math.h>
  # - For glib types (gfloat, guint8, etc), will require include of <glib.h> and
  #   compilation flags of 'pkg-config --cflags glib-2.0'
  def self.stdevFunctions(*types)
    retVal = ''
    types.each { |type|
      retVal << STDEV_TEMPLATE.gsub(/\{TYPE\}/, type).gsub(/\{CAPTYPE\}/, type.capitalize)
    }
    return retVal
  end

  # Make C max functions code for one or more simple C types.
  # - Check that the MAX_VALUE_BY_TYPE hash in this class has keys for all your types.
  # - Requires include of <limits.h>
  # - For glib types (gfloat, guint8, etc), will require include of <glib.h> and
  #   compilation flags of 'pkg-config --cflags glib-2.0'
  def self.maxFunctions(*types)
    retVal = ''
    types.each { |type|
      minValue = MIN_VALUE_BY_TYPE[type]
      retVal << MAX_TEMPLATE.gsub(/\{TYPE\}/, type).gsub(/\{CAPTYPE\}/, type.capitalize).gsub(/\{MIN_VALUE\}/, minValue)
    }
    return retVal
  end

  # Make C min functions code for one or more simple C types.
  # - Requires include of <limits.h>
  # - For glib types (gfloat, guint8, etc), will require include of <glib.h> and
  #   compilation flags of 'pkg-config --cflags glib-2.0'
  def self.minFunctions(*types)
    retVal = ''
    types.each { |type|
      maxValue = MAX_VALUE_BY_TYPE[type]
      retVal << MIN_TEMPLATE.gsub(/\{TYPE\}/, type).gsub(/\{CAPTYPE\}/, type.capitalize).gsub(/\{MAX_VALUE\}/, maxValue)
    }
    return retVal
  end

  # Make C sum functions code for one or more simple C types.
  # - For glib types (gfloat, guint8, etc), will require include of <glib.h> and
  #   compilation flags of 'pkg-config --cflags glib-2.0'
  def self.sumFunctions(*types)
    retVal = ''
    types.each { |type|
      retVal << SUM_TEMPLATE.gsub(/\{TYPE\}/, type).gsub(/\{CAPTYPE\}/, type.capitalize)
    }
    return retVal
  end

  # Returns array of compile flags for the types identified by the argument Symbols.
  # - supports :base, :math, and :glib
  def self.compileFlags(*flagTypes)
    retVal = []
    flagTypes.each { |flagType|
      retVal << case flagType
        when :base
          BASE_COMPILE_FLAGS
        when :math
          MATHLIB_COMPILE_FLAGS
        when :glib
          GLIB_COMPILE_FLAGS
        when :zlib
          ZLIB_COMPILE_FLAGS
        when :debug
          DEBUG_COMPILE_FLAGS
      end
    }
    return retVal
  end
end
end; end
