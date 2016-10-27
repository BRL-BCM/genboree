#http://doc.bioperl.org/releases/bioperl-1.0.2/Bio/DB/GFF/Adaptor/dbi/mysqlopt.html#CODE16

module BRL; module SQL
	# Default bin sizes used if not provided
	MAX_BIN = 1_000_000_000
	MIN_BIN = 1000

  class Binning

		def bin (min=MIN_BIN,start=0,stop=MAX_BIN)
			tier = min
			binStart = 0
			binEnd = 1

			while (binStart != binEnd) do
				division = start.to_i/tier.to_i
				binStart = division.to_i
				division = stop.to_i/tier.to_i
				binEnd = division.to_i
				break if(binStart == binEnd)
				tier *= 10;
			end

			return binName(tier, binStart)
		end

		def binName(tier, pos)
			sprintf("%d.%06d", tier, pos)
		end

		def binBot(tier, pos)
  		retVal = pos.to_i/tier.to_i
  		# This -1 stuff is actually not correct and not what C version does.
  		# But it's making the bins a little bigger on the bottom side and pulling the
  		# right annotations out. Fear == not changed.
  		retVal -= 1
  		return binName(tier, (retVal > 0 ? retVal-1 : 0)).to_f
		end

		def binTop(tier, pos)
			return binName(tier, pos.to_i/tier.to_i).to_f
		end

	  def makeBinSQLWhereExpression(start=0, stop=MAX_BIN, minbin=MIN_BIN, maxbin=MAX_BIN)
	  	# start/stop should be provided in most cases, and will be the
	    # start/stop of the range we are querying.
	    # minbin and maxbin may be provided, but I think in most cases
	    # they have the values MIN_BIN and MAX_BIN from the fmeta table

	    # We're building part of a query query.
	    bins = Array.new()

	    tier = maxbin
	    # Let's create the "fbin" lines for the query...storing
	    # the SQL string and the bind values in the two arrays
	    # declared above.
	    while (tier >= minbin) do
	      tierStart = binBot(tier, start)
	      tierStop  = binTop(tier, stop)
	      if(tierStart == tierStop)
	        bins << "(fbin=#{tierStart})" # add this new String to the array
	      else
	        bins << "(fbin between #{tierStart} and #{tierStop})" # add new String to array
	      end
	      tier /= 10
	    end # done making all the SQL's fbin lines for the query

	    # Let's join all the SQL's fbin lines together
	    query = '(   '
	    query << bins.join("\nOR ")
	    query << '   )'
	    # Return this part of the query...we've finished the hard part
	    # The caller will put it within their where clause for their query.
	    return query
	  end
	end
end ; end #module BRL; module SQL
