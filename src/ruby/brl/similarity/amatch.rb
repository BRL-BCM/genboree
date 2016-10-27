require 'amatch'

# ##################################################################
# FIX: restores backward compatibility with older versions of
#      Amatch which had an Amatch class with a new() that returned
#      a levenshtein matcher by default
# ##################################################################
begin
  testObj = Amatch.new("t")
rescue NoMethodError => err # Must be using the new version
  module Amatch
    def self.new(str)
      return Amatch::Levenshtein.new(str)
    end
  end
end
