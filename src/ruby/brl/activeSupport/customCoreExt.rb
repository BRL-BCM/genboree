require 'brl/util/util'
require 'brl/activeSupport/activeSupport'
# Needed for variablize to work
require 'active_support/core_ext/string'
require 'active_support/core_ext/object/blank'

# These our own core extensions/monkey-patching but are DEPENDENT ON ActiveSupport being
# available. So not suitable for brl/util/util.rb where we do most of that kind of thing.
module CustomCoreExt
end

class String
  def self.variableize(str, asSym=false)
    retVal = str
    if(str)
      retVal = str.gsub(/\\./, "\v").split('.').map { |yy| yy.parameterize.capitalize.tr('-', '_') }.join().decapitalize
      retVal = retVal.sub(/^(\d)/) { |dd| "_#{dd}" }
    end
    return (asSym ? retVal.to_sym : retVal)
  end

  def variableize(asSym=false)
    return self.class.variableize(self, asSym)
  end
end
