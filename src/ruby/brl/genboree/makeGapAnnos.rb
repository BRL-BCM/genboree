#!/usr/bin/env ruby

# ##############################################################################
# LIBRARIES
# - The first 3 are standard for all apps.
# ##############################################################################
require 'interval'              # Implements Interval arithmetic!!!
require 'brl/util/util'
require 'brl/util/textFileUtil'

class Interval
  # Dependent inversion of interval with respect to another interval
  # - this finds the 'gaps'
  # - works on Interval::Simple or Interval::Multiple
  # - assumes Intervals are integers! The library assumes Intervals
  #   from the set of all Real numbers, so this method is a very
  #   special case/assumption. (also we use the word "inversion"
  #   differently than the mathematical inversion used in the library)
  def self.dInvertInteger(iv, dIv)
    invertIntervals = Interval[]
    if(iv.empty?)
      invertIntervals = dIv.dup
    else
      ivComponents = iv.components
      numInvertIntervals = ivComponents.length + 1
      
      numInvertIntervals.times { |ii|
        if(ii == 0)
          invertIntervals = invertIntervals | Interval[dIv.inf, ivComponents[ii].inf - 1]
        elsif(ii == numInvertIntervals - 1)
          invertIntervals = invertIntervals | Interval[ivComponents[ii-1].sup + 1, dIv.sup ]
        else
          invertIntervals = invertIntervals | Interval[ivComponents[ii-1].sup + 1, ivComponents[ii].inf - 1]
        end
      }
    end
    return invertIntervals
  end
end

# First, read in the annotations we are testing coverage for
# - key hash by chromosome
# - each chromosome will have array of annotations (as Arrays), but
#   we are going to sort those, to make analysis a little faster
# - notice that we also "precompute" an Interval for each test set
#   annotation, adding it as the 2nd last element of the anno array
# - notice that we also set aside the "coverage" Interval for each
#   anno as the last element of the anno array
testSet = Hash.new {|hh,kk| hh[kk] = [] }
origTestSet = Hash.new {|hh,kk| hh[kk] = [] }
File.open(ARGV[0]) { |ff|
  ff.each { |line|
    line.strip!
    next if(line !~ /\S/ or line =~ /^\s*#/ or line =~ /^\s*\[/)
    tAnno = line.split(/\t/)
    # skip unless it looks like an annotation line
    next unless(tAnno.length >= 10)
    # we want coords already as numbers, for speed later (plus less mem)
    tAnno[5] = tAnno[5].to_i
    tAnno[6] = tAnno[6].to_i
    if(tAnno[5] > tAnno[6])
      tAnno[5], tAnno[6] = tAnno[6], tAnno[5]
    end
    # add an Interval for this annotation
    testIv = Interval[tAnno[5], tAnno[6]]
    tAnno << testIv
    # add an empty Interval for tracking the coverage
    coverIv = Interval[]
    tAnno << coverIv
    # store the annotation
    testSet[tAnno[4]] << tAnno.dup
  }
}

# Sort the annotations in each chromosome by position
testSet.each_key { |chrom|
  testSet[chrom].sort! {|aa, bb| 
    retVal = (aa[5] <=> bb[5])
    # if starts match, sort using ends
    retVal = (aa[6] <=> bb[6]) if(retVal == 0)
    retVal
  }
}

# Next go through each covering annotation 
File.open(ARGV[1]) { |ff|
  ff.each { |line|
    # First, get the covering annotation:
    line.strip!
    next if(line !~ /\S/ or line =~ /^\s*#/ or line =~ /^\s*\[/)
    cAnno = line.split(/\t/)
    # skip unless it looks like an annotation line
    next unless(cAnno.length >= 10)
    cAnno[5] = cAnno[5].to_i
    cAnno[6] = cAnno[6].to_i
    if(cAnno[5] > cAnno[6])
      cAnno[5], cAnno[6] = cAnno[6], cAnno[5]
    end
    
    # Second, get an Interval object corresponding to the covering
    # annotation.
    cIv = Interval[cAnno[5], cAnno[6]]
    
    # Next, go through ALL test set annotations on the same chromosome
    # and use Interval arithmetic to track coverage automatically.
    # But use as much short-cutting as possible to avoid unneeded work
    testSet[cAnno[4]].each { |tAnno|
      # TWO FAST SHORT-CUTS:
      # 1. If the end of the tAnno is less than the start of cAnno, we
      # aren't looking at tAnnos near the cAnno yet, skip.
      next if(tAnno[6] < cAnno[5])
      # 2. If the start of the tAnno is greater than the end of cAnno,
      # then we are past the cAnno and can skip the rest of the tAnnos,
      # because they will also be beyond the end of the cAnno. This is
      # a key short-cut for O(n*m) operations.
      break if(tAnno[5] > cAnno[6])
      # (These short cuts are equivalent (but way faster, due to the
      #  break out of the loop), to testing if tAnno and cAnno overlap)
      
      # FOUND tAnno COVERED BY THIS cAnno
      # We will now record the 'coverage' of the tAnno using interval
      # arithmetic. This is simple if you test it in irb, but to
      # explain:
      # - the Interval(s) of tAnno that are covered are stored in tAnno[-1]
      # - the Interval corresponding to tAnno is stored in tAnno[-2]
      # - to update the Interval(s) of tAnno that are covered, we compute:
      #   . the *intersection* of tAnno's Interval with the *union* of all
      #     already-covered Intervals and cAnno
      #   . this will combine any overlapping covered intervals and keep non-
      #     overlapping covered intervals as a list
      # Seriously, try it out for a few "reads" in irb that cover some
      # big "bac". It works.
      tAnno[-1] = tAnno[-2] & (Interval.union(tAnno[-1], cIv))
    }
  }
}

# Now, each annotation in testSet contains an Interval (possibly a *set*
# of Intervals) of all its regions that are covered.
testSet.each_key { |chrom|
  testSet[chrom].each { |tAnno| 
    tAnno[-1] = Interval.dInvertInteger(tAnno[-1], tAnno[-2])
  }
}

# Finally, go through each anno in the testSet and print out annotations
# corresponding to gaps where it is not covered.
# - we will "group" all gaps for a particular testSet annotation
# - each exon in a gene will have a unique name, but all the gaps in
#   coverage of that exon will have the same name
seenNames = Hash.new { |hh, kk| hh[kk] = 0 }
# Set a type, so we get a different track
lffType = 'NotCovered'
# Print each annotation's gaps
testSet.each_key { |chrom|
  testSet[chrom].each { |tAnno|
    # Get gap intervals
    gIv = tAnno.pop # Remove the 'gap' interval
    tIv = tAnno.pop # Remove the anno interval
    unless(gIv.empty?)
      # Make the name of the gap annotations
      seenNames[tAnno[1]] += 1
      ver = seenNames[tAnno[1]]
      lffName = "#{tAnno[1]}.#{ver}"
      # Set the type, name, and fix the optional fields if not present
      tAnno[2] = lffType
      tAnno[1] = lffName
      tAnno[10] = '.' if(tAnno[10].nil? or tAnno[10] !~ /\S/)
      tAnno[11] = '.' if(tAnno[11].nil? or tAnno[11] !~ /\S/)
      tAnno[12] = '' if(tAnno[12].nil? or tAnno[12] !~ /\S/)
      tAnno[12] += ';' unless(tAnno[12].nil? or tAnno[12].empty? or tAnno[12] !~ /\S/ or tAnno[12] =~ /;$/)
      origAVPs = tAnno[12]
      # Go through each gap interval and output as lff
      gIvComponents = gIv.components
      gIvComponents.each { |gIvComp|
        tAnno[5] = gIvComp.inf
        tAnno[6] = gIvComp.sup
        # let's track how many gaps per tAnno in the output
        tAnno[12] = origAVPs + " numCoverageGaps=#{gIvComponents.length}; "
        puts tAnno.join("\t")
      }
    end
  }
}

exit(0)
