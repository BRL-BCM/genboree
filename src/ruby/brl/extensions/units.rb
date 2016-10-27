require 'brl/util/util'
require 'ruby-units'

# Open the {Unit} class from the "units" gem and add a couple of class methods.
class Unit
  # Get the list of "scales" known to Unit. Scales are nano, pico, mega, kilo, etc.
  #   They precede the actual unit abbreviation, so they are "prefixes".
  #   e.g. mL, cm
  # @return [Array<String>] A list of known scales.
  # @example
  #   Unit.scales()
  def self.scales()
    # Return prefixes--scales--known to Unit, but sorted
    # alphabetically with ties broken by case-sensitive compare
    return Unit.prefix_regex.to_s.split(/\|/).sort { |aa,bb|
      retVal = (aa.downcase<=>bb.downcase)
      (retVal = (aa<=>bb)) if(retVal==0)
      retVal
    }
  end

  # Given a scale-less ("m" not "cm") unit name:
  #   find all unit definitions which include that as an alias.
  # @note Some unit names/abbreviations are used for SEVERAL types of unit.
  #   So you check that yours is one of the ones found.
  # @param [String] unitAlias The unit abbreviation in question
  # @return [Array<Hash>] For convenience each record in
  #   return Array has 3 keys:
  #   :name, :alises, :def
  # @example
  #   Unit.findUnits("m")
  # @example
  #   Unit.findUnits("M")
  # @example
  #   Unit.findUnits("M").first[:aliases]
  # @example
  #   Unit.findUnits("M").map { |udef| udef[:def].kind }
  # @example
  #   Unit.findUnits("M").map { |udef| { udef[:def].kind => udef[:def].name} }
  def Unit.findUnits(unitAlias)
    retVal = []
    # Visit each known unit definition
    Unit.definitions.each_key { |udefId|
     udefVal = Unit.definitions[udefId]
     # File ALL aliases within this unit definitition which match our unitAlias
     matches = udefVal.aliases.find { |xx|
       xx =~ /\b#{unitAlias}\b/ }
       if(matches and !matches.empty?)
         retVal << {
           :name => udefVal.name,
           :aliases => udefVal.aliases,
           :def => udefVal
         }
      end
    }
    return retVal
  end

  # Return a new unit based on this one by changing its "units": e.g. change 5 m to 5 km
  def setUnits(units)
    Unit("#{self.scalar} #{units}")
  end
end

# ----------------------------------------------------------------------------------
# CUSTOM UNIT DEFINITIONS
# ----------------------------------------------------------------------------------

# New: MONTHS (1/12 of Year)
Unit.define("month") { |month|
  month.definition = Unit("1 year") / 12.0
  month.aliases    = %w{ month mon months mons mo }
  month.display_name = "Month"
}

# Mod: Gravities (x G)
Unit.redefine!("gee") { |gee|
  gee.display_name = "xG"
  gee.aliases += [ "xG", "xg" ]
}


# Mod: cubic mm (1 cubic mm = 1 micro liter)
Unit.define("mm^3") { |mm3|
    mm3.definition = Unit("1 uL") 
    mm3.aliases = [ "cubic mm", "cubic millimeter", "mm3" ]
    mm3.display_name = "Micro liter"
}


# Mod: Particles (Prt)
Unit.define("particle") { |particle|
    particle.definition = Unit.new("1 count") 
    particle.aliases = [ "particles", "prt" ]
    particle.display_name = "particle"
}

