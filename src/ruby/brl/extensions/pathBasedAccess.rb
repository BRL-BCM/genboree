require 'brl/util/util'

module BRL ; module Extensions ; module PathBasedAccess
  def byKeyPath( keyPath, opts={ :autoTrySymbols => true } )
    retVal = nil
    trySyms = opts[:autoTrySymbols]
    unless( keyPath =~ /^\$\./ )
      raise ArgumentError, "ERROR: path-based querying not currently supported, so your paths MUST be rooted at the top of the nested data structure. You asked for 'all sub-docs that match #{keyPath.inspect} ANYWHERE within the data structure', which (a) we don't support yet and (b) is very expensive recursive visiting of ALL keys and ALL indices in your data structure."
    end
    keyPath = keyPath.gsub(/\\./, "\v")
    keys = keyPath.split('.', -1).map { |kk| kk.gsub(/\v/, '.' ) }
    keys.shift
    tmp = self
    keys.each_index { |ii|
      kk = keys[ii]
      #$stderr.puts "\ttmp: #{tmp.inspect}\n\tkk: #{kk.inspect}\n\n"
      if( kk =~ /^\[(\d+)\]$/ )
        idx = $1.to_i
        tmp = ( tmp.is_a?( Array ) ? tmp[idx] : nil )
      else
        if( tmp.is_a?(Hash) )
          tmp1 = tmp[kk]
          if( tmp1.nil? and kk.size > 0 and trySyms )
            tmp1 = tmp[kk.to_sym]
          end
          tmp = tmp1
        else
          tmp = nil
        end
      end
      break if( tmp.nil? )
    }
    retVal = tmp if( tmp != self )
    return retVal
  end
  alias_method :byPath, :byKeyPath
end ; end ; end # module BRL ; module Extensions ; module PathBasedAccess

class Hash
  include BRL::Extensions::PathBasedAccess
end

class Array
  include BRL::Extensions::PathBasedAccess
end
