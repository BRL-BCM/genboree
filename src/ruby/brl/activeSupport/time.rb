
require 'time'
require 'json'

# Open the Time class in order to add (or re-add)
#   a sensible to_json() method, since Rails can't do something smart
#   and Ruby JSON gem is too smart.
class Time

  # Convert the {Time} instance to a {String}, suitable
  #   for use as values within JSON and parseable back to a {Time}
  # @param [Array,nil] args Sucks up all OPTIONAL args into a variable
  #   for DISPOSAL (i.e. if provide, args are unused; generally only provided
  #   by JSON gem and Rails internals)
  # @return [String] the time object, as an RFC 822 formatted JSON string (i.e. with quotes in place)
  def to_json(*args)
    return "\"#{self.rfc822()}\""
  end
end
