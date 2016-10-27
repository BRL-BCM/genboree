require 'brl/util/util'           # ARJ 11/13/2002 12:27PM Make sure to include this to get Range extensions

module BRL ; module Similarity
  
  # -----------------------------------------------
  # Interface Class abstracting hits from a comparison tool
  # -----------------------------------------------
  # * Implementing classes inherit from this
  # * All methods in the _Interface Methods_ section must be properly implemented
  #   by the inheriting class; else errors raised when called
  # * Methods in the _Overridable Methods_ section are implemented, but can be
  #   overridden to return more useful values or for better performance (e.g.
  #   direct calculation rather than incurring method-call overhead)
  # * Methods in the _Help Methods_ section should be left alone
  # * Hit coordinates are assumed to be 0-based, half open. [start, end)
  # * Hit start comes before hit stop. (i.e. start <= stop, always)
  # * LFF is 1-based, closed. [start, end] ; start <= stop
  # * Native hit format returned by to_s() could be 1-based, closed OR 0-based, half open
  # * Native hit format returned by to_s() may or may not have start <= stop (e.g. blast hits)
  class ComparisonHit
    
    # -----------------------------------------------
    # :section: Interface Methods
    # -----------------------------------------------
    # Implement each of these methods.
    # * NOTE: Many of these methods could be simple instance attributes.
    #   It may be EASIEST and FASTEST PERFORMING (little bit) to implement the
    #   getters and setters below using "attr_accessor".
    # * This is certainly the fastest/clearest implementation.
    # * Use instance variables matching the method names below. Refer to them
    #   within the implementation as @methodName or self.methodName.
    # * Let Ruby create the getters and setters for you where appropriate via:
    #   attr_accessor :methodName
    # * I believe doing this in the child class will override these explicit
    #   method definitions in this parent class.
    # -----------------------------------------------
    
    # Create hit object from a line of text.
    # * Parse line & initialize data structures and instance variables.
    # * If the line of text doesn't look like a hit in the proper format,
    #   raise an ArgumentError.
    # [+lineStr+]   String. The line text.
    # _raises_      ArgumentError. If lineStr is badly formatted.
    # _returns_     n/a
    def initialize(lineStr)
    end
    
    # Replace current data with hit data from a line of text.
    # * This is for _reuse_ of this object.
    # * Existing data structures should be cleared and all instance variables
    #   minimally nil'd.
    # * If the line of text doesn't look like a hit in the proper format,
    #   raise an ArgumentError.
    # [+lineStr+]   String. The line text.
    # _raises_      ArgumentError. If lineStr is badly formatted.
    # _returns_     self
    def replace(lineStr)
      raiseNotImplemented()
    end

    # GET the score from the hit.
    # * Returns an 'alignment score' for the hit.
    # * The caller may provide up to four parameters to influence how the
    #   score is calculated.
    # * HOWEVER, these parameters could be _ignored_ by the implementation
    #   (e.g. if using some other score rather than a typical 'alignment score')
    # * NOTE: larger == more significant (i.e. not a p-value or something).
    # _returns_
    def score(matchReward=2, mismatchPenalty=1, gapOpenPenalty=2, gapExtension=1)
      raiseNotImplemented()
    end
    
    # SET the score for the hit.
    # [+score+]     Numeric. The score.
    # _returns_     Numeric
    def score=(score)
      raiseNotImplemented()
    end
    
    # GET the number of base-pair matches (exact or estimated) from the hit.
    # * If not available, an estimate or even the self.score() could be used if it's a Fixnum.
    # * But this method must return a Fixnum that can be used for a sensible sorting of hits.
    # _returns_
    def numMatches()
      raiseNotImplemented()
    end
    
    # SET the number of base-pair matches (exact or estimated) from the hit.
    # [+numMatches+]    Fixnum. Number of base-pair matches.
    # _returns_         Fixnum
    def numMatches=(numMatches)
      raiseNotImplemented()
    end
    
    # GET the query name from this hit.
    # _returns_     String
    def qName()
      raiseNotImplemented()
    end
    
    # SET the query name for this hit.
    # [+qName+]     String. The query name.
    # _returns_     String
    def qName=(qName)
      raiseNotImplemented()
    end
        
    # GET the start of the hit on _query_.
    # * Coordinates are 0-based, half open. qStart <= qEnd, always
    # _returns_         Fixnum
    def qStart()
      raiseNotImplemented()
    end
    
    # SET the start of the hit on the _query_.
    # * Coordinates are 0-based, half open. qStart <= qEnd, always
    # [+qStart+]        Fixnum. Start of hit on _query_.
    # _returns_         Fixnum
    def qStart=(qStart)
      raiseNotImplemented()
    end
    
    # GET the stop of the hit on _query_.
    # * Coordinates are 0-based, half open. qStart <= qEnd, always
    # _returns_         Fixnum
    def qEnd()
      raiseNotImplemented()
    end
    
    # SET the stop of the hit on the _query_.
    # * Coordinates are 0-based, half open. qStart <= qEnd, always
    # [+qEnd+]         Fixnum. Stop of hit on _query_.
    # _returns_         Fixnum
    def qEnd=(qEnd)
      raiseNotImplemented()
    end
    
    # GET the full query size.
    # * This is the full size of the query itself, or a reasonable estimate.
    # * This may be used to filter hits for queries that are too short to be
    #   reliably mapped (e.g. Sanger reads < 110 bases long). Contextual.
    # * This may be used to calculate the query match density.
    # * If not available, return a reasonable estimate based on available data,
    #   or, failing that, a very large number (e.g. Integer::MAX32).
    # _returns_     Fixnum
    def qSize()
      raiseNotImplemented()
    end
    
    # SET the full query size for this hit.
    # * This is the full size of the query itself, or a reasonable estimate.
    # [+qSize+]     Fixnum. Full query size.
    # _returns_     Fixnum
    def qSize=(qSize)
      raiseNotImplemented()
    end
    
    # GET the number of gap bases from the hit on the _query_, or a reasonable estimate.
    # * This may be used to filter hits that have too many gap bases relative to the
    #   query, and thus the hit has very low query coherence.
    # * If not available, return a reasonable estimate based on available data,
    #   or, failing that, 0 as the most conservative value.
    # _returns_     Fixnum
    def qNumGapBases()
      raiseNotImplemented()
    end
    
    # SET the number of gap bases from the hit on the _query_, or a reasonable estimate.
    # [+qNumGapBases+]  Fixnum. Num gap bases from the hit on the _query_.
    # _returns_         Fixnum
    def qNumGapBases=(qNumGapBases)
      raiseNotImplemented()
    end
    
    # GET the target name (e.g. chromosome) from this hit.
    # _returns_     String. The target name.
    def tName()
      raiseNotImplemented()
    end
    
    # SET the target name (eg chromosome) for this hit.
    # [+tName+]     String. The target name.
    # _returns_     String
    def tName=(tName)
      raiseNotImplemented()
    end
    
    # GET the start of the hit on the _target_ (eg chromosome).
    # * Coordinates are 0-based, half open. tStart <= tEnd, always
    # _returns_         Fixnum
    def tStart()
      raiseNotImplemented()
    end
    
    # SET the start of the hit on the _target_ (eg chromosome).
    # * Coordinates are 0-based, half open. tStart <= tEnd, always
    # [+tStart+]        Fixnum. Start of hit on _target_.
    # _returns_         Fixnum
    def tStart=(tStart)
      raiseNotImplemented()
    end
    
    # GET the stop of the hit on the _target_ (eg chromosome).
    # * Coordinates are 0-based, half open. tStart <= tEnd, always
    # _returns_         Fixnum
    def tEnd()
      raiseNotImplemented()
    end
    
    # SET the stop of the hit on the _target_ (eg chromosome).
    # * Coordinates are 0-based, half open. tStart <= tEnd, always
    # [+tEnd+]         Fixnum. Stop of hit on _target_.
    # _returns_         Fixnum
    def tEnd=(tEnd)
      raiseNotImplemented()
    end
    
    # GET the number of gap bases from the hit on the _target_, or a reasonable estimate.
    # * This may be used to filter hits that have too many gap bases relative to the
    #   target. (e.g. the query is smeared on the target by introducing lots
    #   of target gaps in the alignment).
    # * If not available, return a reasonable estimate based on available data,
    #   or, failing that, 0 as the most conservative value.
    # _returns_     Fixnum
    def tNumGapBases()
      raiseNotImplemented()
    end
    
    # SET the number of gap bases from the hit on the _target_, or a reasonable estimate.
    # [+tNumGapBases+]  Fixnum. Num gap bases from the hit on the _query_.
    # _returns_         Fixnum
    def tNumGapBases=(tNumGapBases)
      raiseNotImplemented()
    end
    
    # GET the orientation (+/-) of the hit, relative to the _target_.
    # * If not available, return '+'
    # _returns_         String : '+' or '-'
    def orientation()
      raiseNotImplemented()
    end
    
    # SET the orientation (+/-) of the hit, relative to the _target_.
    # [+orient+]           String : '+' or '-'
    # _returns_            String
    def orientation=(orient)
      raiseNotImplemented()
    end
    
    # GET the hit as an LFF line.
    # * Coordinates in LFF are 1-based, half open. [start, end]
    # * Provide sensible defaults for lffType, lffSubtype, and lffClass
    # _returns_     String
    def to_lff(lffType='Abstract', lffSubtype='Hit', lffClass='Hits')
      raiseNotImplemented()
    end
  
    # GET the hit as an array of field values.
    # * Native field order for the hit.
    # * Should roughly match the native text representation from to_s() or initialize().
    # _returns_     Array
    def to_a()
      raiseNotImplemented()
    end
    
    # GET the field (column) names for the array returned by to_a().
    # _returns_     Array
    def columnHeaders()
      raiseNotImplemented()
    end
    
    # -----------------------------------------------
    # :section: Overridable Methods
    # -----------------------------------------------
    # These can be reimplemented to return more accurate values or to improve
    # efficiency (since they are mainly implemented by calling other methods and
    # this incurs method-call overhead that can be significant for millions of hits.)
    # * Else the provided implementations will be used.
    # -----------------------------------------------
    
    # GET the span of the hit on the _query_.
    # * For most hit formats, this will be qEnd-qStart.
    # * Override using instance variables for speed.
    # _returns_     Fixnum
    def qSpan()
      return (self.qEnd() - self.qStart())
    end
    
    # GET the span of the hit on the _target_.
    # * For most hit formats, this will be tEnd-tStart.
    # * Override using instance variables for speed.
    # _returns_     Fixnum
    def tSpan()
      return (self.tEnd() - self.tStart())
    end
    
    # GET the position of the first base of the query on the target or [more
    # likely] a reasonable estimate from the available data.
    # * This may used for mapping the whole query as best as possible, not just
    #   the part(s) involved in hit(s).
    # _returns_     Fixnum
    def firstBasePos()
      if(self.orientation() == "+")
				zeroBasePos = self.tStart() - self.qStart()
			else
				zeroBasePos = self.tEnd() - self.qStart()
      end
      return zeroBasePos
    end
    
    # GET the percent of the query that has identity with the target, or a
    # reasonable estimate.
    # * Note: percentage is a unit whose value falls between 0.0 and 100.0.
    # _returns_     Numeric
    def queryPercentIdentity()
      return (self.numMatches().to_f / self.qSize()) * 100.0
    end

    # GET the number of base-pairs identified as repeats from the hit.
    # * For most hit formats, this data will not be available.
    # * If it is (e.g. for blat hits) return the correct value.
    # _returns_     Fixnum
    def numRepeatMatches()
      return 0
    end
    
    # GET the number of base-pairs identified as repeats from the hit.
    # * For most hit formats, this data will not be available.
    # * Thus the default implementation does nothing and returns 0 (see numRepeatMatches()).
    # [+numMatches+]    Fixnum. Number of base-pair matches.
    # _returns_         Fixnum
    def numRepeatMatches=(numRepeats)
      return 0
    end
    
    # GET the number of query gap bases as a percentage of the hit's query span.
    # * Note: percentage is a unit whose value falls between 0.0 and 100.0.
    # _returns_         Numeric 
    def queryPercentGapBases()
      return (self.qNumGapBases.to_f / self.qSpan()) * 100.0
    end
    
    # GET the number of target gap bases as a percentage of the hit's target span.
    # * Note: percentage is a unit whose value falls between 0.0 and 100.0.
    # _returns_         Numeric 
    def targetPercentGapBases()
      return (self.tNumGapBases.to_f / self.tSpan()) * 100.0
    end
    
    # -----------------------------------------------
    # :section: Helper Methods
    # -----------------------------------------------
    # Don't implement these. They are not part of the interface.
    # Feel free to make use of them in implementation as appropriate.
    # -----------------------------------------------
    
    # Raise a NotImplementedError using the caller context for the original method.
    # _returns_     raises exception
    def raiseNotImplemented()
      methName = thisMethod(caller)
      raise NotImplementedError, "\nERROR: the method #{self.class}##{methName} has not been implemented!\n"
    end
    
    # Get the name of the method [who calls this one, actually]. Not needed in
    # Ruby 1.9 since there are constants for that. Returns nil if method can't
    # be determined (top level scope for eg.)
    # [+callerContext+]   Array. The 'caller' array for the original method
    # _returns_           String or nil
    def thisMethod(callerContext)
      ((callerContext[0] =~ /`([^']*)'/ and $1) or nil)
    end
  end
end ; end
