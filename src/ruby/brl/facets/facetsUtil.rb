require 'brl/util/util'
# Retry load if looks like facets 1.X won't work...maybe 2.X
begin
  require 'facet/interval'
rescue LoadError => lerr
  require 'facets/interval'
end

class Interval
  # Make it MUTABLE!
  def first=(value)
    @first = value
    @direction = (@first < @last ? 1 : (@first==@last ? 0 : -1) )
  end

  # Make it MUTABLE!
  def last=(value)
    @last = value
    @direction = (@first < @last ? 1 : (@first==@last ? 0 : -1) )
  end

  # Make interval comparable!
  def <=>(anInterval)
    aiMin, aiMax = anInterval.min, anInterval.max
    selfMin, selfMax = self.min, self.max
    selfExclMin, aiExclMin = self.exclude_min?(), anInterval.exclude_min?()
    selfExclMax, aiExclMax = self.exclude_max?(), anInterval.exclude_max?()

    # Compare min sentinals
    retVal = selfMin <=> aiMin
    # Resolve ties where exclude_mins differs
    if( retVal == 0 )
      if( selfExclMin and !aiExclMin )
        retVal = 1
      elsif( !selfExclMin and aiExclMin )
        retVal = -1
      end
    end
    # If *still* a tie, then min sentinals are equal and exclude_mins are same
    if( retVal == 0 )
      retVal = selfMax <=> aiMax
      # Resolve ties where exlcude_max differs
      if(retVal == 0 )
        if( selfExclMax and !aiExclMax )
          retVal = -1
        elsif( !selfExclMax and aiExclMax )
          retVal = 1
        end
      end
    end
    return retVal
  end

  def exclude_min?()
    return (@direction >= 0) ? self.exclude_begin?() : self.exclude_end?()
  end

  def exclude_max?()
    return (self.direction >= 0) ? self.exclude_end?() : self.exclude_begin?()
  end

  def contains?(anInterval)
    raise(TypeError, "\nERROR: Interval#contains?() takes an Interval class (facet/interval).") unless(anInterval.kind_of?(Interval))
    aiMin, aiMax = anInterval.min, anInterval.max
    selfMin, selfMax = self.min, self.max

    # Check smaller (min) end of anInterval
    if( self.exclude_min?() )
      if( anInterval.exclude_min?() )
        return false unless(aiMin >= selfMin)
      else
        return false unless(aiMin > selfMin)
      end
    else
      return false unless(aiMin >= selfMin)
    end
    # Check larger (max) end of anInterval
    if( self.exclude_max?() )
      if( anInterval.exclude_max?() )
          return false unless(aiMax <= selfMax)
      else
          return false unless(aiMax < selfMax)
      end
    else
      return false unless(aiMax <= selfMax)
    end
    # self must contain anInterval
    return true
  end

  def overlaps?(anInterval)
    raise(TypeError, "\nERROR: Interval#overlaps?() takes an Interval class (facet/interval).") unless(anInterval.kind_of?(Interval))
    aiMin, aiMax = anInterval.min, anInterval.max
    selfMin, selfMax = self.min, self.max

    # Check smaller (min) end of anInterval
    if( self.exclude_max?() )
      if( anInterval.exclude_min?() )
        return false unless(aiMin <= selfMax)
      else
        return false unless(aiMin < selfMax)
      end
    else
      return false unless(aiMin < selfMax)
    end
    # Check smaller (min) of self
    if( anInterval.exclude_max?() )
      if( self.exclude_min?() )
        return false unless(selfMin <= aiMax)
      else
        return false unless(selfMin < aiMax)
      end
    else
      return false unless(selfMin < aiMax)
    end
    # Must overlap
    return true
  end

  def within?(anInterval)
    raise(TypeError, "\nERROR: Interval#within?() takes an Interval class (facet/interval).") unless(anInterval.kind_of?(Interval))
    return anInterval.contains?(self)
  end
end
