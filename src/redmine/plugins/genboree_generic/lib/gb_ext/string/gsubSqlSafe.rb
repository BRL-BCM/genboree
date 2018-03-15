class String
  def gsubSqlSafe(matcher, replaceStr=nil, &block)
    cb = (block_given? ? Proc.new : block)
    # First, mask out any escaped single quote char sequences prevent in the replacement str
    #   (e.g. from Mysql2::Client.escape() on user provided input)
    replaceStr = replaceStr.gsub(/\\'/, "\v")
    # Now perform gsub as usual, without having to worry about the two-char sequence \'
    #   being a backreference to the "post-match" string (i.e. to $' which Ruby populates
    #   when applying your matcher as a *regexp* [always uses regexp]) corrupting the expected results.
    if( cb ) # then no replaceStr, using block to do replacement
      retVal = self.gsub(mm, &cb)
    else # usual replaceStr and no block
      retVal = self.gsub(matcher, replaceStr)
    end
    # Finally, unmask the two-char \' sequence so it appears in the output (presumably it's the correctly sql-escaped ' chars in user's input)
    # * We need \\ for a raw \, and we need \\' for the raw ' [because Ruby would see escaped sequence \' as meaning "postmatch value here"
    retVal.gsub(/\v/, "\\\\'")
  end
end
