#!/usr/bin/env ruby
$VERBOSE = nil
require 'memoist'
require 'brl/extensions/memoist'
require 'brl/util/util'

module BRL ; module Util ; module Linux
  class IOStat
    METHOD_OPTS = {
      :runIostat                => { :opts => { :units => :K, :type => :dev, :want => :lines, :stripTitle => true, :stripBlankLines => true } },
      :diskTotalBytesByActivity => { :activity => :both },
      :initialize               => { :opts => { :reuseIostatOutput => true } }
    }
    MEMOIZED_INSTANCE_METHODS = [
      :runIostat,
      :diskTotalBytesByActivity
    ]

    def self.diskTotalBytesByActivity( activity=METHOD_OPTS[__method__][:activity], iostatLines=nil )
      retVal = nil
      if(iostatLines)
        outLines = iostatLines
      else
        outLines = self.runIostat( { :type => :dev, :want => :lines, :units => :K, :stripTitle => true, :stripBlankLines => true } )
      end

      # Find columns with the KB read and KB written
      deviceLine = outLines.find { |line| line =~ /^Device/i }
      if(deviceLine)
        fields = deviceLine.split(/\s+/)
        kbReadIdx = fields.index('kB_read')
        kbWrtnIdx = fields.index('kB_wrtn')
        # Next, add up byte totals for all disk type devices
        # * We'll use the rule of thumb that disk devices start with 'hd' or 'sd'
        diskLines = outLines.find_all { |line| line =~ /^(?:s|h)d/ }
        if( diskLines and !diskLines.empty? )
          retVal = 0
          diskLines.each { |line|
            fields = line.split(/\s+/)
            kbRead = fields[kbReadIdx].to_i rescue 0
            kbWrtn = fields[kbWrtnIdx].to_i rescue 0
            retVal += kbRead if( activity == :both or activity == :read )
            retVal += kbWrtn if( activity == :both or activity == :wrtn )
          }
          # Return bytes, but employed KB option with iostat
          retVal *= 1024
        end
      end
      return retVal
    end

    def self.runIostat( opts=METHOD_OPTS[__method__][:opts] )
      opts = METHOD_OPTS[__method__][:opts].merge( opts )

      # Build iostat command itself
      cmd = 'iostat '
      cmd << '-k ' if( opts[:units] == :K )
      cmd << '-m ' if( opts[:units] == :M )
      cmd << '-d ' if( opts[:type] == :dev ) # devices, such as disks
      # Add filters can do on command line
      cmd << ' | sed 1d ' if( opts[:stripTitle] )
      cmd << ' | sed -r \'/^\s*$/d\' ' if( opts[:stripBlankLines] )

      # Run command, capture output
      out = `#{cmd}`

      if( opts[:want] == :lines )
        retVal = out.lines
      else
        retVal = out
      end

      #$stderr.debugPuts(__FILE__, __method__, 'DEBUG', "Called iostat (in class method) via this cmd:\n\t#{cmd}")
      return out
    end

    def initialize( opts=METHOD_OPTS[__method__][:opts] )
      opts = METHOD_OPTS[__method__][:opts].merge( opts )
      @reuseIostatOutput = opts[:reuseIostatOutput]
      initMemoization() if( @reuseIostatOutput )
    end

    # Memoization is ON (:reuseIostatOutput option for new() to disable), so that a given call to the {#runIostat}
    #   method will only be done ONCE and then reused by methods needing that kind of iostat output to answer
    #   question. This has the benefit one doing a given iostat command (and any sed pipes) ONCE, but is INAPPROPRIATE
    #   if you're wanting to monitor or have the stats periodically updated.
    #   * If you want updated stats, either:
    #     1. Make a new IOStat instance
    #     2. Clear the memoization cache via iostatObj.unmemoize_all so it has to refress
    # @note This initialized memoization for THIS INSTANCE. Other instance should be unaffected. This is good/safe
    #   given that memoization CANNOT BE DISABLED. This is why we didn't do it on the class in general be rather
    #   this instance's specific singleton_class. We also DON'T want the class methods which have the same name
    #   as the object methods memoized!!!!
    # @note Of course, that means for this to have ANY value, you need to reuse this same instance over and over.
    def initMemoization()
      class << self
        extend Memoist
        # Memoize instance methods, but via the METACLASS level (will not memoize IOStat.runIostat this way.)
        self::MEMOIZED_INSTANCE_METHODS.each { |meth| memoize meth }
      end
    end

    def runIostat( opts=METHOD_OPTS[__method__][:opts] )
      opts = METHOD_OPTS[__method__][:opts].merge( opts )
      return self.class::runIostat( opts )
    end

    def diskTotalBytesByActivity( activity=METHOD_OPTS[__method__][:activity] )
      return self.class::diskTotalBytesByActivity(activity, runIostat() )
    end

    def clear()
      # MUST be using our brl/extensions/memoist override/patch for this to work in this kkind of scenario.
      unmemoize_all
    end
  end
end ; end ; end
