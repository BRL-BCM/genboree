
# This module defines functions that can be used in modelValidator and autoIdGenerator
module BRL; module Genboree; module KB; module Util; module AutoId
  ARG_PHLDR = "%s"
  GEN_PHLDR = "%G"

  # Support function for DOMAINS[/^autoID\(/] because it was becoming too complicated for no "\n" characters
  def parseAutoIdDomain(vv, *xx)
    rv = nil
    defaultLength = 6
    defaultPadding = true
    defaultDelim = "-"
    paddingModes = ["increment"] # modes whose middle part will be padded with 0s to <length>

    # setup: regexp is autoID(prefix, matchMode[length;<future matchMode arguments>], suffix, delimiter) where 
    #   delimiter is optional and defaults to "-" and 
    #   [] part(s) are optional arguments to uniqMode delimited by ";"
    preSufRegex = /\s*([^\(\t\n,]*?)\s*/
    uniqModeRegex = /\s*(uniqNum|uniqAlphaNum|increment)\s*/
    uniqModeArgsRegex = /(?:\[\s*([^;\s\]]+)\s*\])?/ # add future arguments as ";"-delimited e.g. ";\s*([^;\s\]]+)\s*" and adjust match group numbers
    delimRegex = /\s*([^\(\t\s\n,]*?)\s*/
    autoIdRegex = /^autoID\(#{preSufRegex.source},#{uniqModeRegex.source}#{uniqModeArgsRegex.source},#{preSufRegex.source}(?:,#{delimRegex.source})?\)/

    # attempt match and parse
    vv.to_s.strip =~ autoIdRegex
    if($&)
      # set static parts
      rv = { 
        :prefix => $1.strip, 
        :uniqMode => $2, 
        :suffix => $4, 
        :delim => $5.nil? ? defaultDelim : $5
      }

      # parse optional uniqModeArgs
      length = ( $3.nil? ? nil : $3.to_i )
      rv[:length] = ( length.nil? ? defaultLength : length )

      # add padding for modes supporting it
      modeSupportsPadding = paddingModes.include?(rv[:uniqMode])
      rv[:padding] = (modeSupportsPadding ? true : false)
      rv[:uniqModeMatcher] = getAutoIdGenMatcher(rv[:uniqMode], rv[:length], modeSupportsPadding)
    end
    return rv
  end

  # Parse autoIDTemplate domain string into an object that can be used to validate values
  #  against the domain and to generate content for values in the domain
  # @param [String] vv the domain to parse: of the form 
  #   autoIDTemplate(<templateString>, <generatorType>[<generatorArguments>])
  #   where the templateString contains at least one {GEN_PHLDR} and zero or more {ARG_PHLDR}
  # @todo share more with parseAutoIdDomain
  def parseAutoIdTemplateDomain(vv, *xx)
    rv = nil
    defaultLength = 6

    templateRegex = /\s*(.*?)\s*/
    uniqModeRegex = /\s*(uniqNum|uniqAlphaNum|increment)\s*/
    uniqModeArgsRegex = /(?:\[\s*([^;\s\]]+)\s*\])?/ # add future arguments as ";"-delimited e.g. ";\s*([^;\s\]]+)\s*" and adjust match group numbers
    regex = /^autoIDTemplate\(#{templateRegex.source},#{uniqModeRegex.source}#{uniqModeArgsRegex.source}\)/

    matchData = regex.match(vv.to_s.strip)
    if(matchData.nil?)
      rv = nil
    else
      rv = {
        :template => matchData[1],
        :uniqMode => matchData[2]
      }

      # validate the template: (1) {GEN_PHLDR} is required
      gIndex = rv[:template].index(GEN_PHLDR)
      if(gIndex.nil?)
        # error: {GEN_PHLDR} is required
        rv = nil
      else
        # validate template: (2) must be a delimiter between {GEN_PHLDR} and {ARG_PHLDR} so that
        #   portions of {ARG_PHLDR} are not interpreted as the generated ID e.g. {ARG_PHLDR}{GEN_PHLDR} => KJENS1000001
        #   vs. {ARG_PHLDR}-{GEN_PHLDR} => KJENS1-000001
        # @note fixed template characters such as the 1 in "#{ARG_PHLDR}1#{GEN_PHLDR}" are fine because they will
        #   anchor the regex
        prevStart = gIndex - ARG_PHLDR.size
        prevEnd = prevStart + ARG_PHLDR.size
        isPrev = (rv[:template][prevStart...prevEnd] == ARG_PHLDR)
        nextStart = gIndex + GEN_PHLDR.size
        nextEnd = nextStart + ARG_PHLDR.size
        isNext = (rv[:template][nextStart...nextEnd] == ARG_PHLDR)
        if(isPrev or isNext)
          rv = nil
        end
      end

      unless(rv.nil?)
        # then template is valid, finish parsing domain
        # parse optional length
        length = (matchData[3].nil? ? nil : matchData[3].to_i)
        rv[:length] = (length.nil? ? defaultLength : length)
  
        # count singleton "%" (not "%%")
        tempTokens = rv[:template].split("%%")
        rv[:placeholders] = 0
        tempTokens.each { |token|
          rv[:placeholders] += token.count("%")
        }
        rv[:placeholders] -= 1 # for required {GEN_PHLDR}

        # add uniqModeMatcher to pdom
        composeAutoIdTemplateRegexp!(rv)
      end
    end
    return rv
  end
  
  def validateAutoId(vv, dflt, pdom, *xx)
    rv = dflt
    vv = vv.to_s.strip
    if(vv.nil? or vv !~ /\S/)
      rv = :CONTENT_MISSING
    else
      if(vv =~ composeAutoIdRegexp(pdom))
        rv = vv
      else
        rv = dflt
      end
    end
    return rv
  end

  # Values of the autoIDTemplate domain are parsed as comma-separated values which
  #   must be the same number as pdom[:placeholders] and may be an empty string
  #   (for pdom[:placeholders] = 0)
  # @note commas are forbidden here and in autoID @todo allow them through escaping?
  def validateAutoIdTemplate(vv, dflt, pdom, *xx)
    rv = dflt
    # strings enclosed in "[" "]" are "final" (after content generation) values
    vv = vv.to_s.strip
    finalRegex = /^\[[^\]]+\]$/
    begin
      matchData = finalRegex.match(vv)
      if(matchData.nil?)
        # then verify that the provided arguments are in the same number as the template placeholders
        pdom[:arguments] = vv.split(",")
        if(pdom[:arguments].length != pdom[:placeholders])
          # then the arguments are not valid; they do not match the template string
          rv = dflt
        else
          # then arguments are valid, mark this field as needing content generation
          rv = :CONTENT_MISSING
        end
      else
        # then validate generated content or user input
        if(vv =~ composeAutoIdTemplateRegexp!(pdom))
          rv = vv
        else
          rv = dflt
        end
      end
    rescue => err
      rv = dflt
    end
    return rv
  end

  # Utility to help distinguish values in this domain between
  #   (1) a string that should be transformed according to pdom[:template]
  #   (2) a string that already has been transformed
  def flagValueAsGenerated(template)
    return "[" + template + "]"
  end

  # Support function for DOMAINS[/^autoID\(/] to make a regexp that can be used to
  #   (1) validate fields in the domain
  #   (2) extract middle portion from autoID
  # @return [Regexp] a regexp whose first match group will provide the middle part of an autoID
  def composeAutoIdRegexp(pdom)
    prefix = (pdom[:prefix].to_s =~ /\S/ ? "#{pdom[:prefix]}#{pdom[:delim]}" : "")
    suffix = (pdom[:suffix].to_s =~ /\S/ ? "#{pdom[:delim]}#{pdom[:suffix]}" : "")
    rv = /^#{Regexp.escape(prefix)}#{pdom[:uniqModeMatcher].source}#{Regexp.escape(suffix)}$/
    return rv
  end

  # Return a Regexp whose first match group is the generated portion of an autoID or nil
  #   if failure
  # @param [Hash] pdom result from DOMAINS[<domain>][:parseDomain] proc
  def composeAutoIdTemplateRegexp!(pdom)
    rv = nil
    template = pdom[:template].dup()

    # "final" value in autoIDTemplate domain must be enclosed in square brackets
    template = flagValueAsGenerated(template)

    # Replace any {GEN_PHLDR} in the template string with the auto id part
    # Regexp escape the template because it should be interpretted literally
    # @todo need to forbid "%" in case of accidental {GEN_PHLDR} or escape or &c.
    err = nil
    gsubTemplateRegex = /#{Regexp.escape(GEN_PHLDR)}/
    if(template.index(gsubTemplateRegex))
      tokens = template.split(gsubTemplateRegex)
      escTokens = tokens.map { |xx| Regexp.escape(xx) }
      matcher = getAutoIdGenMatcher(pdom[:uniqMode], pdom[:length], true) # @todo true
      template = escTokens.join(matcher.source)
    else
      # error: {GEN_PHLDR} is required
      rv = nil
      err = true
    end

    unless(err)
      if(pdom.key?(:arguments))
        template = fillTemplateArgs(template, ARG_PHLDR, pdom[:arguments])
      else
        template.gsub!(ARG_PHLDR, ".+?")
      end
  
      # either way, "%" values from template have been replaced
      pdom[:uniqModeMatcher] = Regexp.new(template)
      rv = pdom[:uniqModeMatcher]
    end

    return rv
  end

  # In addition to fillTemplateArgs, replace occurences of {GEN_PHLDR} with a @generatedStr@
  def fillTemplate(template, generatedStr, arguments, genPhldr=GEN_PHLDR, argPhldr=ARG_PHLDR)
    template = fillTemplateArgs(template, arguments, argPhldr)
    return template.gsub(genPhldr, generatedStr)
  end

  # Replace occurrences of @replaceStr@ in @template@ with values in @arguments@
  def fillTemplateArgs(template, arguments, argPhldr=ARG_PHLDR)
    # try to replace occurrences of arg placeholder with arguments
    ii = 0
    index = template.index(argPhldr)
    while(!index.nil?)
      value = arguments[ii]
      if(value.nil?)
        err = true
        break
      end
      template[index...index+argPhldr.length] = value
      index = template.index(argPhldr)
      ii += 1
    end
    return template
  end

  def getAutoIdGenMatcher(uniqMode, length, modeSupportsPadding=true)
    # Set uniqModeMatcher based on length and padding
    uniqModeMatcher = nil
    defaultMatcher = /([A-Za-z0-9]+)/
    if(uniqMode == "uniqNum" or uniqMode == "increment")
      if(modeSupportsPadding and !length.nil?)
        # then adjust uniqModeMatcher to require padding for the given length
        uniqModeMatcher = /(\d{#{length}}\d*)/ # at least {length} digits
      else
        # then no special padding is required
        uniqModeMatcher = /(\d+)/
      end
    else
      uniqModeMatcher = defaultMatcher
    end
    uniqModeMatcher = uniqModeMatcher.nil? ? defaultMatcher : uniqModeMatcher
  end
end; end; end; end; end

