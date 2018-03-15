require 'brl/util/util'

class String

  # Capitalize only the first letter. "capitalize()" doesn't do this and
  #   Rails "titleize()" definitely does weird things if camel cased or normal
  #   english sentence.
  # @return [String] A new {String} whose first character has been capitalized.
  def capitalizeFirst()
    self.sub(/^./, &:upcase)
  end

  # @see #capitalizeFirst
  def capitalizeFirst!()
    self.replace( self.capitalizeFirst )
    self
  end

  # Wraps long string to multiple lines.
  # @note Intended for use on single-line string. You can ask it to remove any pre-existing newlines.
  #   (This is also useful when you intend on wrapping via something other than newline, to make special single line string).
  # @note Mainly intended for \n line wrapping, with optional line-prefix for indenting and such.
  # @note May not be wise on very huge strings. It's all done in RAM and arrays of words/lines and things are created
  #   at various points, so doing this on huge strings in contraindicated.
  # @note The ASCII bell character \a is used internally for identifying word boundries without making
  #   a huge array of individual word strings. If the input text contains \a (wth?) it will (a) act as a word-break
  #   and will be stripped out of final results.
  # @param [Fixnam] len Line length. Defaults to 80. For non-HTML email, 72 is good.
  # @param [Hash{Symbol,Object}] opts Optional options hash to tweak behavior.
  #   @option opts [String] :prefix Line prefix. Will be place immediately before each line. Can be used for
  #     bullets or indenting (via bunch of spaces). Default is no prefix ('').
  #   @option opts [String] :sep Line separator. By default Unix line separator char "\n" is used,
  #     but can use the platform one via $/ or other various things ("\t", " ; ") for various effects.
  #   @option opts [Symbol] :prefixWhich Symbol indicating when to prefix. By default is it :all. But can provide
  #     :onlyFirst to have only the first line prefixed, or :notFirst to have all line but the first prefixed (which
  #     can give hanging indents and such). To disable prefixing use :prefix='', making this option irrelevant.
  #   @option opts [boolean] :preUnwrap Should we first remove any pre-existing *newlines* ("\n" specifically) before
  #     applying wrapping?
  #   @option opts [String,Array<String>] :wordDelim A character or set of ordered characters that can be used to
  #     identify "words" suitable for wrapping-points. By default this is [' '], i.e. words are identified via spaces
  #     and then broken only if word is still too long for the line. If an {Array} of strings is supplied, they are
  #     used sequentially to identify sensible wrap points. For example if :workDelim=>[' ', '.'] then first words are
  #     identified via usual ' ' space, but then if "word" is still too long, then '.' is used to break those long
  #     words. Only after that is a word broken in the middle; this example can work well for ~sensible wrapping of
  #     property-paths which can easily be >1 line worth of chars, especially if no spaces used in prop names.
  # @return [String] New, wrapped string.
  def wordWrap( len=80, opts={ :prefix=>'', :sep=>"\n", :prefixWhich => :all, :preUnwrap => false, :wordDelim => [ ' ' ] } )
    if( self.size <= len )
      retVal = self
    else
      prefix = ( opts[:prefix] or '' )
      sep = ( opts[:sep] or "\n" ) # platform line separator
      escSep = Regexp.escape( sep )
      preWhich = ( opts[:prefixWhich] or :all )
      preUnwrap = ( opts[:preUnwrap] or false)
      delims = ( opts[:wordDelim] ? opts[:wordDelim].to_a : [ ' ' ] )
      len = ( ( len > (prefix.size + sep.size) ) ? (len - prefix.size - sep.size) : 1 )

      # Remove any existing wrapping if asked (wrapping already wrapped lines may give odd results.)
      text = ( preUnwrap ? self.gsub(sep, '') : self )
      # Break any long words into two [or more] words (via delims, used in sequence [i.e. order of preference])
      delimReSetStr = delims.map{ |xx| Regexp.escape(xx[0,1]) }.join('')
      # Add the line-separator to the delimiter list since it's de factor going to be there
      # - and may be wanting to preserve any that already exist in the string (i.e. for preUnwrap = false cases)
      delimReSetStr = "#{delimReSetStr}#{escSep}"
      buff = '' # Words in buffer are separated by \a (non-display bell)
      text.scan(/.+?(?:[#{delimReSetStr}]|$)/).each { |word|
        if( word.length > len )
          buff << word.gsub(/(.{1,#{len}})/, "\\1\a")
        else
          buff << "#{word}\a"
        end
      }
      lineNum = 0
      retVal = buff.split(/#{escSep}/).map { |line| # generally just 1 big line at this point, unless had some newlines within already
        if( (line.length > len) and ((line.length - line.count("\a")) > len) )
          ll = []
          line.scan( /(.{1,#{len}})(?:\a+|$)/ ) { |arg|
            lnPrefix = ( (preWhich == :all or (preWhich == :onlyFirst and lineNum == 0) or (preWhich == :notFirst and lineNum != 0 )) ? prefix : '' )
            if( lineNum <= 0 ) # Leave the first line alone, only wrapped ones need fixing with lstrip
              emit = arg.first
            else
              emit = arg.first.lstrip
            end
            lineNum += 1
            ll << "#{lnPrefix}#{emit.gsub("\a", '')}"
          }
          ll
        else
          lnPrefix = ( (preWhich == :all or (preWhich == :onlyFirst and lineNum == 0) or (preWhich == :notFirst and lineNum != 0 )) ? prefix : '' )
          line.lstrip! unless( lineNum <= 0 ) # Leave the first line alone, only wrapped ones need fixing with lstrip
          lineNum += 1
          "#{lnPrefix}#{line.gsub("\a", '')}"
        end
      }.flatten.join(sep)
    end
    return retVal
  end

  # @see #wordWrap
  def wordWrap!( len=80, opts={ :prefix=>'', :sep=>"\n", :prefixWhich => :all, :preUnwrap => false }  )
    self.replace( self.wordWrap( len, opts ) )
    self
  end
end
