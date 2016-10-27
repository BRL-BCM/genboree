require 'cgi'
require 'yaml'
require 'rein'
require 'json'
require 'brl/util/util'

class JSON2ReinRule
  STRING_TYPE, NUMBER_TYPE, BOOLEAN_TYPE = 'text', 'number', 'boolean'
  OP_MAP =  {
              'contains'            => 'contains?',
              'not contains'        => 'notContains?',
              'begins with'         => 'beginsWith?',
              'not begins with'     => 'notBeginsWith?',
              'ends with'           => 'endsWith?',
              'not ends with'       => 'notEndsWith?',
              'is present'          => 'isPresent?',
              'is not present'      => 'isNotPresent?',
              '>'                   => '>',
              '<'                   => '<',
              '>='                  => '>=',
              '<='                  => '<=',
              '='                   => '=',
              '!='                  => '!=',
              'between'             => 'between?',
              'not between'         => 'notBetween?',
              'is true'             => 'isTrue?',
              'is false'            => 'isFalse?',
              'is empty'            => 'isEmpty?',
              'is not empty'        => 'isNotEmpty?'
            }
  TYPE2PREFIX_MAP = {
                      'text'        => 'str_',
                      'number'      => 'num_',
                      'boolean'     => 'bool_'
                    }

  attr_accessor :ruleSpec

  def initialize(resolutionType=Rein::RuleSpecObj::ALL_REQUIRED)
    @ruleSpec = Rein::RuleSpecObj.new(resolutionType)
  end

  def resolutionType()
    return @ruleSpec['conflict']
  end

  def resolutionType=(resolutionType)
    return @ruleSpec['conflict'] = resolutionType
  end

  def parseJsonStr(jsonStr)
    jsonData = JSON.parse(jsonStr)
    # Currently, the json data is an array of rules which are
    # encoded as hashes with certain properties & values

    # Loop over each rule hash in the json and use the info to add
    # a new rule to the ruleSpec.
    ruleCount = 0
    jsonData.each { |ruleHash|
      ruleCount += 1
      # ---- Rule name ----
      ruleName = "Rule #{ruleCount}"
      # ---- Condition ----
      # Left operand
      leftOperand = ruleHash['attribute']
      leftOperand = leftOperand.gsub(/\\/, '\\\\').gsub(/\'/, '\\\\\'') # a \ becomes 2*\ ; a ' becomes 2*\ and a '
      leftOperand = '\'' + leftOperand + '\'' # the left operand is surrounded in '
      # Clean operation and datatype first (in case slight bugs in json string)
      ruleHash['operation'].strip!
      ruleHash['datatype'].strip!
      # Operation and right operand
      if(ruleHash['operation'] =~ /between/i) # a complex right-hand operand
        # Going to need a range string from the values list
        if(ruleHash['datatype'] == 'number')
          rangeString = "(#{ruleHash['values'][0].to_f}..#{ruleHash['values'][1].to_f})"
        else # assume string
          rightOperand1 = ruleHash['values'][0].to_s
          rightOperand1 = rightOperand1.gsub(/\\/, '\\\\').gsub(/\'/, '\\\\\'') # a \ becomes 2*\ ; a ' becomes 2*\ and a ' in the rule file
          rightOperand1 = '\'' + rightOperand + '\'' # the right operand is surrounded in \' in the rule file
          rightOperand2 = ruleHash['values'][1].to_s
          rightOperand2 = rightOperand2.gsub(/\\/, '\\\\').gsub(/\'/, '\\\\\'') # a \ becomes 2*\ ; a ' becomes 2*\ and a ' in the rule file
          rightOperand2 = '\'' + rightOperand + '\'' # the right operand is surrounded in \' in the rule file
          rangeString = "(#{rightOperand1}..#{rightOperand2})"
        end
        opStr = TYPE2PREFIX_MAP[ruleHash['datatype']] + OP_MAP[ruleHash['operation']]
        opRightStr = "#{opStr} #{rangeString}"
      else # simple right-hand operand
        opRightStr = "#{OP_MAP[ruleHash['operation']]} "
        # add ignoreCase modifier if appropriate
        if(ruleHash['datatype'] == 'text' and !ruleHash['caseSensitive'] and (ruleHash['operation'] !~ /present/))
          opRightStr.gsub!(/\?/, '_ignoreCase?')
        end
        # write the right-hand operand appropriately by data type
        unless(ruleHash['values'].empty? or (ruleHash['values'][0].respond_to?('empty?') and ruleHash['values'][0].empty?))
          if(ruleHash['datatype'] == 'number')
            opRightStr += ruleHash['values'][0].to_s
          elsif(ruleHash['datatype'] == 'boolean')
            opRightStr += ruleHash['values'][0].to_s.downcase
          else # assume string
            rightOperand = ruleHash['values'][0].to_s
            rightOperand = rightOperand.gsub(/\\/, '\\\\').gsub(/\'/, '\\\\\'') # a  \ becomes 2*\ ; a ' becomes 2*\ and a ' in the rule file
            rightOperand = '\'' + rightOperand + '\'' # the right operand is surrounded in \" in the rule file
            opRightStr += rightOperand
          end
        else # assume just a boolean question
          opRightStr += 'true'
        end
      end
      conditionStr = leftOperand + ' ' + opRightStr
      conditionStr = CGI.escape(conditionStr)
      $stderr.puts "CONDITION STR:"
      $stderr.puts conditionStr
      # ---- Action ----
      actions = [ 'passed += 1' ]
      # ---- Done, add new rule ----
      @ruleSpec.addRule(ruleName, conditionStr, actions, required=false, priority=nil)
    }
    return @ruleSpec
  end
end
