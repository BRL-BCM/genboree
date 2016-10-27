
# --------------------------------------------------------------------
# !!!!! NOTE: BRL Customized Version of the Original RinRuby GEM !!!!!
# ------------------------------------------------------------------
# - addresses problems with not being able to capture the stderr messages from R
#   for programmatic use in scripting/pipelines
#   . accessors for (a) does it look like R reported and error and (b) what was that error message?
#   . new eval() code added
#   . minor helper methods added
#   . changed requires so stderr can be captured from R subprocess
#   . changed namespace so it doesn't interfere with any installed RinRuby gem
#   . ascii ord/chr checking should be Ruby 1.8 vs 1.9 safe due to brl/util/util usage
# - some code reorganization to allow BRL maintenance
# ------------------------------------------------------------------

# ------------------------------------------------------------------
# ORGINAL CLASS COMMENTS FOLLOWS:
# ------------------------------------------------------------------
#=RinRuby: Accessing the R[http://www.r-project.org] interpreter from pure Ruby
#
#RinRuby is a Ruby library that integrates the R interpreter in Ruby, making R's statistical routines and graphics available within Ruby.  The library consists of a single Ruby script that is simple to install and does not require any special compilation or installation of R.  Since the library is 100% pure Ruby, it works on a variety of operating systems, Ruby implementations, and versions of R.  RinRuby's methods are simple, making for readable code.  The {website [rinruby.ddahl.org]}[http://rinruby.ddahl.org] describes RinRuby usage, provides comprehensive documentation, gives several examples, and discusses RinRuby's implementation.
#
#Below is a simple example of RinRuby usage for simple linear regression. The simulation parameters are defined in Ruby, computations are performed in R, and Ruby reports the results. In a more elaborate application, the simulation parameter might come from input from a graphical user interface, the statistical analysis might be more involved, and the results might be an HTML page or PDF report.
#
#<b>Code</b>:
#
#      require "rinruby"
#      n = 10
#      beta_0 = 1
#      beta_1 = 0.25
#      alpha = 0.05
#      seed = 23423
#      R.x = (1..n).entries
#      R.eval <<EOF
#          set.seed(#{seed})
#          y <- #{beta_0} + #{beta_1}*x + rnorm(#{n})
#          fit <- lm( y ~ x )
#          est <- round(coef(fit),3)
#          pvalue <- summary(fit)$coefficients[2,4]
#      EOF
#      puts "E(y|x) ~= #{R.est[0]} + #{R.est[1]} * x"
#      if R.pvalue < alpha
#        puts "Reject the null hypothesis and conclude that x and y are related."
#      else
#        puts "There is insufficient evidence to conclude that x and y are related."
#      end
#
#<b>Output</b>:
#
#      E(y|x) ~= 1.264 + 0.273 * x
#      Reject the null hypothesis and conclude that x and y are related.
#
#Coded by:: David B. Dahl
#Documented by:: David B. Dahl & Scott Crawford
#Copyright:: 2005-2009
#Web page:: http://rinruby.ddahl.org
#E-mail::   mailto:rinruby@ddahl.org
#License::  GNU Lesser General Public License (LGPL), version 3 or later
#
#--
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>
#++
#
#
#The files "java" and "readline" are used when available to add functionality.
# ------------------------------------------------------------------

require 'matrix'
require 'socket'
require 'open3'
require 'brl/util/util'

module BRL ; module Stats ; module R
  # RinRuby facilitates Ruby<-R interaction without needing R script file intermediaries and
  #   without the strangeness of rsruby. It does this by talking to an R subprocess through pipes,
  #   and through R's TCP socket interface. TCP is used for doing assignment and pulls of R values,
  #   while the pipes are used to write R code over to R and monitor its stdout/stderr for messages.
  #
  # [following is adapted from the original]
  #
  # RinRuby is invoked within a Ruby script (or the interactive "irb" prompt denoted >>) using:
  #
  # @example Require RinRuby and getting the default R instance at @R@ (a global):
  #   require "brl/stats/R/rinruby"
  #
  # The previous statement reads the definition of the RinRuby class into the current Ruby interpreter
  #   and creates an instance of the RinRuby class named @R@. There is a second method for starting an
  #  instance of R which allows the user to use any name for the instance, in this case @myr@:
  #
  # @example Creating RinRuby instances
  #   require "brl/stats/R/rinruby"
  #   myr = BRL::Stats::R::RinRuby.new
  #   myr.eval "rnorm(1)"
  #
  # Any number of _independent instances_ of RinRuby can be created in this way!
  #
  # It may be desirable to change the parameters to the instance of R, but still call it by the name of R.
  #   In that case the old instance of R which was created with the 'require "rinruby"' statement should be
  #   closed first using the quit method which is explained below.
  # @note Unless the previous instance is killed, it will continue to use system resources
  #   until exiting Ruby.
  # @example The following shows an example by changing the parameter echo and using quit() to close the previous R instance:
  #   require "rinruby"
  #   R.quit
  #   R = RinRuby.new(false)
  # @note This class ALWAYs tries to set up an R subprocess when loaded/required, if the global constant @R@ is not already defined.
  #   This will consume memory and other resources (including a TCP socket), even if you smartly decide to always use specific
  #   instances of this class. You can avoid the @R@ global (and its subprocess resources), however. Either define the @R@
  #   global up front *before* any require/load of this file (@R = :No_R_Global@). Or you can fix things up *after* a require/load
  #   (or unsure): shutdown the global R and then do the constant assigment (i.e. @R.quit rescue false ; origVerbose,
  #   $VERBOSE = $VERBOSE, nil ; R = :No_R_Global ; $VERBOSE = origVerbose)
  class RinRuby
    VERSION = '2.0.3.brl'
    # @return [Class] Exception class for closed engine
    EngineClosed  = Class.new(Exception)
    # @return [Class] Exception class for R parse error
    ParseError    = Class.new(Exception)

    # @return [Boolean] indicating if the communication with R should be in interactive mode or not
    attr_reader :interactive
    # @return [Boolean] indicating if Readline library is available or not
    attr_reader :readline
    # @return [Boolean] indicating if we should echo R stdout to Ruby stdout. Default is @false@. Changed via {#echo}.
    attr_reader :echo_enabled
    # @return [String]  the path to the R executable. Make sure you have a decent one in your $PATH!
    attr_reader :executable
    # @return [Fixnum]  the port number to use when R is available as a server.
    attr_reader :port_number
    # @return [Fixnum]  the range of ports, starting at #port_number, to randomly pick from when using R as a server
    attr_reader :port_width
    # @return [String]  the domain name of the R server, if using it that way
    attr_reader :hostname
    # @return [Boolean] indicating if it looks like R reported an Error.
    attr_reader :errorReported
    # @return [String]  if {#errorReported} indicates there was an error message from R, this should contain
    #   the standard error text from R's stderr stream [unless redirected to stdout] and with a constant terminal
    #   line introduced to aid reading & parsing.
    attr_reader :errorMsg

    # Constructor.
    #   The arguments listed below can also be provides using a single {Hash} arg, with the parameter names below
    #   as {Symbols} for keys (i.e. named args). Otherwise, the parameters must be provided in the order below.
    # @param [Boolean] echo By setting the echo to @false@, output from R is suppressed, although warnings are still printed.
    #   This option can be changed later by using the echo method. The default is @true@.
    # @param [Boolean] interactive When interactive is @false@, R is run in non-interactive mode, resulting in plots without
    #   an explicit device being written to @Rplots.pdf@. Otherwise (i.e., interactive is @true@), plots are shown on the screen.
    #   Default is @true@.
    # @param [String] executable The path of the R executable (which is "R" in Linux and Mac OS X, or "Rterm.exe" in Windows)
    #   can be set with the executable argument. The default is @nil@ which makes RinRuby use the registry keys to find the
    #   path (on Windows) or use the path defined by @$PATH@ (on Linux and Mac OS X).
    # @param@ [Fixnum] port_number This is the smallest port number on the local host that could be used to pass data between
    #   Ruby and R. The actual port number used depends on port_width.
    # @param [Fixnum] port_width RinRuby will randomly select a uniform number between @port_number@ and @port_number + port_width - 1@
    #   (inclusive) to pass data between Ruby and R. If the randomly selected port is not available, RinRuby will continue selecting
    #    random ports until it finds one that is available. By setting @port_width@ to 1, RinRuby will wait until port_number is available.
    #    Default port_width is 1000.
    def initialize(*args)
      opts = Hash.new
      if(args.size == 1 and args[0].is_a?( Hash))
        opts = args[0]
      else
        unless(args.empty?)
          opts[:echo], opts[:interactive], opts[:executable], opts[:port_number], opts[:port_width] = *args
        end
      end

      default_opts = {:echo=>true, :interactive=>true, :executable=>nil, :port_number=>38442, :port_width=>1000, :hostname=>'127.0.0.1'}
      @opts = default_opts.merge(opts)
      @echo_stderr   = false
      @errorReported = false
      @errorMsg      = nil
      @echo_enabled  = @opts[:echo]
      @interactive   = @opts[:interactive]
      @port_width    = @opts[:port_width]
      @executable    = @opts[:executable]
      @hostname      = @opts[:hostname]
      while(true)
        begin
          @port_number = @opts[:port_number] + rand(port_width)
          @server_socket = TCPServer::new(@hostname, @port_number)
          break
        rescue Errno::EADDRINUSE
          sleep 0.5 if(port_width == 1)
        end
      end

      # Determine OS platform
      @platform = case RUBY_PLATFORM
        when /mswin/ then 'windows'
        when /mingw/ then 'windows'
        when /bccwin/ then 'windows'
        when /cygwin/ then 'windows-cygwin'
        when /java/
          require 'java' #:nodoc:
          if(java.lang.System.getProperty("os.name") =~ /[Ww]indows/)
            'windows-java'
          else
            'default-java'
          end
        else 'default'
      end

      # Set up executable and platform specific options
      if(@executable == nil)
        @executable = ( @platform =~ /windows/ ) ? find_R_on_windows(@platform =~ /cygwin/) : 'R'
      end
      platform_options = []
      if(@interactive)
        begin
          require 'readline'
        rescue LoadError
        end
        @readline = defined?(Readline)
        platform_options << ( ( @platform =~ /windows/ ) ? '--ess' : '' )
      else
        @readline = false
      end

      # Start the R sub-process, getting handles for stdin, stdout, stderr
      cmd = %Q<#{executable} #{platform_options.join(' ')} --slave>
      @writer, @reader, @error = Open3.popen3(cmd)
      raise "Engine closed" if(engineClosed?)

      # Tell R to start listening on a TCP socket.
      @writer.puts <<-EOF
        #{RinRuby_KeepTrying_Variable} <- TRUE
        while ( #{RinRuby_KeepTrying_Variable} ) {
          #{RinRuby_Socket} <- try(suppressWarnings(socketConnection("#{@hostname}", #{@port_number}, blocking=TRUE, open="rb")),TRUE)
          if ( inherits(#{RinRuby_Socket},"try-error") ) {
            Sys.sleep(0.1)
          } else {
            #{RinRuby_KeepTrying_Variable} <- FALSE
          }
        }
        rm(#{RinRuby_KeepTrying_Variable})
      EOF
      r_rinruby_get_value
      r_rinruby_pull
      r_rinruby_parseable
      @socket = @server_socket.accept
      echo(nil,true) if(@platform =~ /.*-java/)      # Redirect error messages on the Java platform
    end

    # The quit method will properly close the bridge between Ruby and R, freeing up system resources.
    #   This method does not need to be run when a Ruby script ends.
    # @return [Boolean] indicating if quit was sucessful.
    def quit()
      retVal = true
      begin
        @writer.puts "q(save='no')"
        @socket.read()
        closeEngine()
        @server_socket.close
        true
      ensure
        closeEngine() unless(engineClosed?)
        @server_socket.close unless @server_socket.closed?
      end
      return retVal
    end

    # The {#eval} instance method passes the R commands contained in the supplied string and displays any
    #   resulting plots or prints the output. It is a key method used to interacte with R.
    # @example This example uses string interpolation to make the argument to first eval method equivalent to @x <- rnorm(10)@. Three invocations of the {#eval} method are used:
    #   sample_size = 10
    #   R.eval "x <- rnorm(#{sample_size})"
    #   R.eval "summary(x)"
    #   R.eval "sd(x)"
    #
    # @example But in this example, a single invoke is possible using a "heredoc":
    #   R.eval <<EOF
    #     x <- rnorm(#{sample_size})
    #     summary(x)
    #     sd(x)
    #   EOF
    #
    # @param [String] string The code which is to be passed to R, for example, @string = "hist(gamma(1000,5,3))"@.
    #   The string can also span several lines of code by use of a here document, as shown:
    # @param [Boolean] echo_override Set the echo behavior for this call only. The default for @echo_override@ is @nil@,
    #   which does not override the current echo behavior.
    # @return [Boolean] indicating if it looks like the R code ran succesfully
    def eval(string, echo_override=nil)
      raise EngineClosed if(engineClosed?)
      echo_enabled = ( echo_override != nil ) ? echo_override : @echo_enabled

      # Write the code plus some "flag/marker" lines to R's stdin
      # - note: if string has syntax errors, the flag/marker line printing is not reached.
      if(complete?(string))
        @writer.puts string
        @writer.puts "warning('#{RinRuby_Stderr_Flag}',immediate.=TRUE)" if(@echo_stderr)
        @writer.puts "print('#{RinRuby_Eval_Flag}')"
      else
        raise ParseError, "Parse error on eval:#{string}"
      end

      # Try to trap the interrupt signal (does a bad job!)
      Signal.trap('INT') {
        @writer.print ''
        @reader.gets if(@platform !~ /java/)
        Signal.trap('INT') { }
        return true
      }

      # Begin parsing the stdout from R, trying to determine if things went ok or not, did
      # we get our marker/flag lines as expected, etc.
      found_eval_flag   = false
      found_stderr_flag = false
      while(true)
        echo_eligible = true
        begin
          line = @reader.gets
        rescue
          return false # <- ugh! return from middle of code when exception raise. Bad design, from original
        end
        unless(line)
          return false # <- ugh! return from middle of code when exception raise. Bad design, from original
        end
        line.strip!
        line = line[8..-1] if(line[0].ord == 27)    # Delete escape sequence
        # Look for expected eval-completed flag/marker:
        if(line == "[1] \"#{RinRuby_Eval_Flag}\"")  # Found our marker/flag (always have a special print() after R command)
          found_eval_flag = true  # All is cool, we got our little marker/flag in output (rather: no syntax error)
          echo_eligible   = false # Don't print this line though, it's for behind the scenes management
        # Else, look for expected warning line when redirecting R stderr to R's stdout
        elsif(@echo_stderr and line == "Warning: #{RinRuby_Stderr_Flag}") # to handle stderr is being sent to stdout (echo_stderr is true)
          found_stderr_flag = true
          echo_eligible = false  # Don't print this warning line, it's for managment of stderr -> stdout echoing
        end

        break if(found_eval_flag && ( found_stderr_flag == @echo_stderr )) # break because we're basically done when we see the special marker/flag line

        # Ugh, premature return from middle of code when exit seen. Bad design, from original.
        return false if(line == RinRuby_Exit_Flag)

        # If it looks like we have a valid R result line, and we're supposed to echo out such lines, do so immediately with a flush
        if(echo_enabled && echo_eligible)
          puts line
          $stdout.flush rescue false
        end
      end

      # Suck up any stderr output from R if appropriate
      unless(@echo_stderr) # then there won't BE any stderr content! sink() is used to send everything (pretty much) to stdout in this case
        lastErrorContent = ''
        # Ensure there will be SOMETHING in R's stderr stream...the end-of-stderr flag/marker line:
        @writer.puts "write('#{RinRuby_Eval_Stderr_Flag}', stderr())"
        @error.readpartial(8192, lastErrorContent) rescue false
        # Does it look like R reported an error?
        if(lastErrorContent =~ /(?:^|\A)Error:? /)
          @errorReported = true
          @errorMsg = lastErrorContent
        else
          @errorReported = false
          @errorMsg = nil
        end
      end
      Signal.trap('INT') { }
      return !@errorReported
    end

    # Data is copied from Ruby to R using the assign method or a short-hand equivalent.
    # @example For assign:
    #   names = ["Lisa","Teasha","Aaron","Thomas"]
    #   R.assign "people", names
    #   R.eval "sort(people)"
    # @example For short-hand assign, one would do:
    #   R.people = names
    #
    # Some care is needed when using the short-hand of the assign method since the label
    #   must be a valid method name in Ruby. For example, @R.copy.of.names = names@ will not work,
    #   but #R.copy_of_names = names# is permissible.
    #
    # The assign method supports Ruby variables of type {Fixnum} (i.e., integer), {Bignum} (i.e., integer),
    #   {Float} (i.e., double), {String}, and {Array}s of one of those three fundamental types. Note that
    #   {Fixnum} or {Bignum} values that exceed the capacity of R's integers are silently converted to doubles.
    #   Data in other formats must be coerced when copying to R.
    #
    # When assigning an array containing differing types of variables, RinRuby will follow R’s conversion
    #   conventions. An array that contains any {String}s will result in a character vector in R. If the array
    #   does not contain any {String}s, but it does contain a {Float} or a large integer (in absolute value),
    #   then the result will be a numeric vector of Doubles in R. If there are only integers that are suffciently
    #   small (in absolute value), then the result will be a numeric vector of integers in R.
    #
    # @param [String] name The name of the variable desired in R.
    # @param [Object] value The value the R variable should have. The assign method supports Ruby variables
    #   of type {Fixnum} (i.e., integer), {Bignum} (i.e., integer), {Float} (i.e., double), {String}, and
    #   {Array}s of one of those three fundamental types. Note that {Fixnum} or {Bignum} values that exceed
    #   the capacity of R's integers are silently converted to doubles. Data in other formats must be coerced when copying to R.
    #
    def assign(name, value)
       raise EngineClosed if(engineClosed?)
      if assignable?(name)
        assign_engine(name,value)
      else
        raise ParseError, "Parse error"
      end
    end

    # Data is copied from R to Ruby using the {#pull} method or a short-hand equivalent.
    # @example The R object @xx@ defined with an {#eval} method can be copied to Ruby object @copy_of_x@ as follows:
    #   R.eval "xx <- rnorm(10)"
    #   copy_of_xx = R.pull("xx")
    #   puts copy_of_xx
    #
    # RinRuby also supports a convenient short-hand notation when the argument to pull is simply a previously-defined
    #   R object (whose name conforms to Ruby's requirements for method names).
    # @example Of a pull short-hand:
    #   copy_of_xx = R.xx
    #
    # The explicit {#assign} method, however, can take an arbitrary R statement.
    # @example Of using {#assign} with an arbitrary R statement
    #  summary_of_xx = R.pull("as.numeric(summary(xx))")
    #  puts summary_of_xx
    #
    # Notice the use above of R's @as.numeric@ function in the examples. This is necessary since the {#pull} method only
    #   supports R vectors which are numeric (i.e., integers or doubles) and character (i.e., strings). Data in other
    #   formats must be coerced in R before copying to Ruby.
    #
    # @param [String] string The name of the variable that should be pulled from R. The {#pull} method only
    #   supports R vectors which are numeric (i.e., integers or doubles) and character (i.e., strings). Data in other
    #   formats must be coerced in R before copying to Ruby.
    # @param [Booleans] singletons : R represents a single number as a vector of length one, but in Ruby it is often
    #   more convenient to use a number rather than an array of length one. Setting @singleton=false@ will cause the
    #   {#pull} method to shed the array, while @singletons=true@ will return the number of string within an array.
    #   Default is @false@.
    # @return [Object] the value pulled from R.
    # @raise [ParseError] when the R code in @string@ looks to have a syntax error.
    def pull(string, singletons=false)
      raise EngineClosed if(engineClosed?)
      if(complete?(string))
        result = pull_engine(string)
        if( !singletons and (result.length == 1) and (result.class != String))
          result = result[0]
        end
      else
        raise ParseError, "Parse error for the R code provided."
      end
      return result
    end

    # Controls whether the {#eval} method displays output from R and, if echo is enabled, whether messages, warnings, and
    #   errors from stderr are also displayed.
    # @param [Boolean] enable If @false@ will turn all output off until the {#echo} method is used again with @enable@
    #   equal to @true@. The default is @nil@, which will return the current setting.
    # @param [Boolean] stderr If @true@, will force messages, warnings, and errors from R to be routed through stdout.
    #   Using stderr redirection is typically not needed for the C implementation of Ruby and is thus not not enabled
    #   by default for this implementation. It is typically necessary for jRuby and is enabled by default in that case.
    #   This redirection works well in practice but it can lead to interleaving output which may confuse RinRuby.
    #    In such cases, stderr redirection should not be used. Echoing must be enabled when using stderr redirection.
    # @return [Array<Boolean>] indicating the current state of echo enabled and stderr redirection.
    # @raise [RuntimeError] if a bad combination of @enable@ and @stderr@ are provided (like @false, @true@)
    def echo(enable=nil,stderr=nil)
      if(enable == false and stderr == true)
        raise "You can only redirect stderr if you are echoing is enabled."
      end
      if(!enable.nil? and enable != @echo_enabled)
        echo(nil, false) unless(enable)
        @echo_enabled = !@echo_enabled
      end
      if(@echo_enabled and !stderr.nil? and stderr != @echo_stderr)
        @echo_stderr = !@echo_stderr
        if(@echo_stderr)
          eval("sink(stdout(),type='message')")
        else
          eval("sink(type='message')")
        end
      end
      [ @echo_enabled, @echo_stderr ]
    end

    # Does the R code in @string@ appear to be valid and free of syntax errors?
    #   Used extensively internally, but also useful externally for scripting/checking/validating.
    # @param [String] string The R code to consider.
    # @return [Boolean] indicating if the R code looks syntactically valid.
    def complete?(string)
      assign_engine(RinRuby_Parse_String, string)
      @writer.puts "rinruby_parseable(#{RinRuby_Parse_String})"
      buffer=""
      @socket.read(4,buffer)
      @writer.puts "rm(#{RinRuby_Parse_String})"
      result = to_signed_int(buffer.unpack('N')[0].to_i)
      return (result == -1 ? false : true)
      # Commented out in original:
      #result = pull_engine("unlist(lapply(c('.*','^Error in parse.*','^Error in parse.*unexpected end of input.*'),
      #  grep,try({parse(text=#{RinRuby_Parse_String}); 1}, silent=TRUE)))")
      #
      #return true if result.length == 1
      #return false if result.length == 3
      #raise ParseError, "Parse error"
    end

    # If a method is called which is not defined, then it is assumed that the user is attempting
    #   to either {#pull} or {#assign} a variable to R. This allows for the short-hand equivalents for {#pull} and {#assign}
    # @example An "assign" short-hand to get value 2 from Ruby over R:
    #   R.xx = 2
    #   # same as:
    #   R.assign("x",2)
    # @example A "pull" short-hand to get value from R's xx variable over to Ruby
    #   nn = R.xx
    #   # same as:
    #   nn = R.pull("xx")
    # @param (see #pull)
    # @param (see #assign)
    # @return (see #pull)
    # @return (see #assign)
    def method_missing(symbol, *args)
      name = symbol.id2name
      if(name =~ /(.*)=$/)
        raise ArgumentError, "You shouldn't assign nil" if(args == [nil])
        super if(args.length != 1)
        assign($1, args[0])
      else
        super if(args.length != 0)
        pull(name)
      end
    end

    # When sending code to Ruby using an interactive prompt, this method will change the prompt to an R prompt.
    #   From the R prompt commands can be sent to R exactly as if the R program was actually running. When the
    #   user is ready to return to Ruby, then the command exit() will return the prompt to Ruby. This is the ideal
    #   situation for the explorative programmer who needs to run several lines of code in R, and see the results
    #   after each command. This is also an easy way to execute loops without the use of a here document. It should
    #   be noted that the prompt command does not work in a script, just Ruby's interactive irb.
    # @param [String] regular_prompt The string used to denote the R prompt.
    # @param [String] continue_prompt The string used to denote R's prompt for an incomplete statement (such as a multiple for loop).
    # @return [Boolean] indicating success
    # @raise [RuntimeError] If this instance is not in interactive mode.
    def prompt(regular_prompt="> ", continue_prompt="+ ")
      # Sanity checks:
      raise "The 'prompt' method only available in 'interactive' mode" unless(@interactive)
      return false unless(eval("0", false)) # <- ugh! return from middle of code when exception raise. Bad design, from original

      prompt = regular_prompt
      while(true)
        cmds = []
        while(true)
          if(@readline and @interactive)
            cmd = Readline.readline(prompt, true)
          else
            print prompt
            $stdout.flush
            cmd = gets.strip
          end
          cmds << cmd
          begin
            if(complete?(cmds.join("\n")))
              prompt = regular_prompt
              break
            else
              prompt = continue_prompt
            end
          rescue
            puts "Parse error"
            prompt = regular_prompt
            cmds = []
            break
          end
        end
        next if(cmds.length == 0)
        break if(cmds.length == 1 and cmds[0] == "exit()")
        break unless(eval(cmds.join("\n"), true))
      end
      return true
    end

    # ------------------------------------------------------------------
    # HELPERS and INTERNAL CONSTANTS
    # ------------------------------------------------------------------

    private

    RinRuby_Type_NotFound     = -2
    RinRuby_Type_Unknown      = -1
    RinRuby_Type_Double       = 0
    RinRuby_Type_Integer      = 1
    RinRuby_Type_String       = 2
    RinRuby_Type_String_Array = 3
    RinRuby_Type_Matrix       = 4

    RinRuby_KeepTrying_Variable = ".RINRUBY.KEEPTRYING.VARIABLE"
    RinRuby_Length_Variable     = ".RINRUBY.PULL.LENGTH.VARIABLE"
    RinRuby_Type_Variable       = ".RINRUBY.PULL.TYPE.VARIABLE"
    RinRuby_Socket              = ".RINRUBY.PULL.SOCKET"
    RinRuby_Variable            = ".RINRUBY.PULL.VARIABLE"
    RinRuby_Parse_String        = ".RINRUBY.PARSE.STRING"
    RinRuby_Eval_Flag           = "RINRUBY.EVAL.FLAG"
    RinRuby_Eval_Stderr_Flag    = "--- RinRuby: R Stderr Stream ---"
    RinRuby_Stderr_Flag         = "RINRUBY.STDERR.FLAG"
    RinRuby_Exit_Flag           = "RINRUBY.EXIT.FLAG"
    RinRuby_Max_Unsigned_Integer      = 2**32
    RinRuby_Half_Max_Unsigned_Integer = 2**31
    RinRuby_NA_R_Integer              = 2**31
    RinRuby_Max_R_Integer             = 2**31-1
    RinRuby_Min_R_Integer             = -2**31+1

    # Define rinruby_parseable() function
    def r_rinruby_parseable()
      @writer.puts <<-EOF
      rinruby_parseable<-function(var) {
        result=try(parse(text=var),TRUE)
        if(inherits(result, "try-error")) {
          writeBin(as.integer(-1),#{RinRuby_Socket}, endian="big")
        } else {
          writeBin(as.integer(1),#{RinRuby_Socket}, endian="big")
        }
      }
      EOF
    end

    # Define function in R to get values
    def r_rinruby_get_value()
      @writer.puts <<-EOF
      rinruby_get_value <-function() {
        value <- NULL
        type <- readBin(#{RinRuby_Socket}, integer(), 1, endian="big")
        length <- readBin(#{RinRuby_Socket},integer(),1,endian="big")
        if ( type == #{RinRuby_Type_Double} ) {
          value <- readBin(#{RinRuby_Socket},numeric(), length,endian="big")
        } else if ( type == #{RinRuby_Type_Integer} ) {
          value <- readBin(#{RinRuby_Socket},integer(), length, endian="big")
        } else if ( type == #{RinRuby_Type_String} ) {
          value <- readBin(#{RinRuby_Socket},character(),1,endian="big")
        } else {
          value <-NULL
        }
        value
      }
      EOF
    end

    # Define function to pull R values to Ruby
    def r_rinruby_pull()
      @writer.puts <<-EOF
      rinruby_pull <-function(var) {
        if ( inherits(var ,"try-error") ) {
          writeBin(as.integer(#{RinRuby_Type_NotFound}),#{RinRuby_Socket},endian="big")
        } else {
          if (is.matrix(var)) {
            writeBin(as.integer(#{RinRuby_Type_Matrix}),#{RinRuby_Socket},endian="big")
            writeBin(as.integer(dim(var)[1]),#{RinRuby_Socket},endian="big")
            writeBin(as.integer(dim(var)[2]),#{RinRuby_Socket},endian="big")
          }  else if ( is.double(var) ) {
            writeBin(as.integer(#{RinRuby_Type_Double}),#{RinRuby_Socket},endian="big")
            writeBin(as.integer(length(var)),#{RinRuby_Socket},endian="big")
            writeBin(var,#{RinRuby_Socket},endian="big")
          } else if ( is.integer(var) ) {
            writeBin(as.integer(#{RinRuby_Type_Integer}),#{RinRuby_Socket},endian="big")
            writeBin(as.integer(length(var)),#{RinRuby_Socket},endian="big")
            writeBin(var,#{RinRuby_Socket},endian="big")
          } else if ( is.character(var) && ( length(var) == 1 ) ) {
            writeBin(as.integer(#{RinRuby_Type_String}),#{RinRuby_Socket},endian="big")
            writeBin(as.integer(nchar(var)),#{RinRuby_Socket},endian="big")
            writeBin(var,#{RinRuby_Socket},endian="big")
          } else if ( is.character(var) && ( length(var) > 1 ) ) {
            writeBin(as.integer(#{RinRuby_Type_String_Array}),#{RinRuby_Socket},endian="big")
            writeBin(as.integer(length(var)),#{RinRuby_Socket},endian="big")
          } else {
            writeBin(as.integer(#{RinRuby_Type_Unknown}),#{RinRuby_Socket},endian="big")
          }
        }
      }
      EOF
    end

    # Convert arg to a signed integer for passing into R.
    # @param [Integer] y A object that is an integer or can be converted to one.
    def to_signed_int(y)
      if(y.kind_of?(Integer))
        ( y > RinRuby_Half_Max_Unsigned_Integer ) ? -(RinRuby_Max_Unsigned_Integer-y) : ( y == RinRuby_NA_R_Integer ? nil : y )
      else
        y.collect { |x| ( x > RinRuby_Half_Max_Unsigned_Integer ) ? -(RinRuby_Max_Unsigned_Integer-x) : ( x == RinRuby_NA_R_Integer ? nil : x ) }
      end
    end

    # Do prep work for assigning a Ruby variable to an R variable (conversions, etc) and
    #   then actually send it over to R using the TCP socket it is listening on.
    # @param [String] name The name of the R variable to assign to.
    # @param [Object] value The Ruby value to assign to "@name@" in R.
    # @return [Object] the original @value@.
    # @raise [RuntimeError] when the Ruby value is not a supported type/class.
    def assign_engine(name, value)
      original_value = value
      # Special assign for matrixes
      if(value.kind_of?(::Matrix))
        values=value.row_size.times.collect {|i| value.column_size.times.collect {|j| value[i,j]}}.flatten
        eval "#{name}=matrix(c(#{values.join(',')}), #{value.row_size}, #{value.column_size}, TRUE)"
        return original_value
      end

      if(value.kind_of?(String))
        type = RinRuby_Type_String
        length = 1
      elsif(value.kind_of?(Integer))
        if(value >= RinRuby_Min_R_Integer and value <= RinRuby_Max_R_Integer)
          value = [ value.to_i ]
          type = RinRuby_Type_Integer
        else
          value = [ value.to_f ]
          type = RinRuby_Type_Double
        end
        length = 1
      elsif(value.kind_of?(Float))
        value = [ value.to_f ]
        type = RinRuby_Type_Double
        length = 1
      elsif(value.kind_of?(Array))
        begin
          if(value.any? { |x| x.kind_of?(String) })
            eval "#{name} <- character(#{value.length})"
            for index in 0...value.length
              assign_engine("#{name}[#{index}+1]",value[index])
            end
            return original_value
          elsif(value.any? { |x| x.kind_of?(Float) })
            type = RinRuby_Type_Double
            value = value.collect { |x| x.to_f }
          elsif(value.all? { |x| x.kind_of?(Integer) })
            if(value.all? { |x| ( x >= RinRuby_Min_R_Integer ) && ( x <= RinRuby_Max_R_Integer ) })
              type = RinRuby_Type_Integer
            else
              value = value.collect { |x| x.to_f }
              type = RinRuby_Type_Double
            end
          else
            raise "Unsupported data type on Ruby's end"
          end
        rescue
          raise "Unsupported data type on Ruby's end"
        end
        length = value.length
      else
        raise "Unsupported data type on Ruby's end"
      end

      # Send to R.
      @writer.puts "#{name} <- rinruby_get_value()"
      @socket.write([type,length].pack('NN'))
      if(type == RinRuby_Type_String)
        @socket.write(value)
        @socket.write([0].pack('C'))   # zero-terminated strings
      else
        @socket.write(value.pack( ( type==RinRuby_Type_Double ? 'G' : 'N' )*length ))
      end
      original_value
    end

    # Do prep work for pulling a value from R over to the Ruby side (conversions, etc) and
    #   then actually do the pull via the socket R is listening on.
    # @param [String] string The variable or R code to produce the value to pull.
    # @return [Object] the pulled value
    # @raise [RuntimeError] when the data type on R is not supported for pulling.
    def pull_engine(string)
      @writer.puts <<-EOF
        rinruby_pull(try(#{string}))
      EOF

      buffer = ""
      @socket.read(4,buffer)
      type = to_signed_int(buffer.unpack('N')[0].to_i)
      if(type == RinRuby_Type_Unknown)
        raise "Unsupported data type on R's end"
      end
      if(type == RinRuby_Type_NotFound)
        return nil
      end
      @socket.read(4, buffer)
      length = to_signed_int(buffer.unpack('N')[0].to_i)

      if(type == RinRuby_Type_Double)
        @socket.read(8*length,buffer)
        result = buffer.unpack('G'*length)
      elsif(type == RinRuby_Type_Integer)
        @socket.read(4*length,buffer)
        result = to_signed_int(buffer.unpack('N'*length))
      elsif(type == RinRuby_Type_String)
        @socket.read(length,buffer)
        result = buffer.dup
        @socket.read(1,buffer)    # zero-terminated string
        result
      elsif( type == RinRuby_Type_String_Array)
        result = Array.new(length,'')
        for index in 0...length
          result[index] = pull "#{string}[#{index+1}]"
        end
      elsif(type == RinRuby_Type_Matrix)
        rows=length
        @socket.read(4,buffer)
        cols = to_signed_int(buffer.unpack('N')[0].to_i)
        elements = pull("as.vector(#{string})")
        index = 0
        result = Matrix.rows(rows.times.collect { |i|
          cols.times.collect { |j|
            elements[(j*rows)+i]
          }
        })
        def result.length; 2; end
      else
        raise "Unsupported data type on Ruby's end"
      end
      result
    end

    # Does the R code in @string@ look assignable?
    # @param [String] string The R code to consider.
    # @return [Boolean] indicating if the R code looks assignable.
    # @raise [ParseError] If the R code has syntax errors or is not actually assignable.
    def assignable?(string)
      retVal = false
      raise ParseError, "Parse error" unless(complete?(string))
      assign_engine(RinRuby_Parse_String,string)
      result = pull_engine("as.integer(ifelse(inherits(try({eval(parse(text=paste(#{RinRuby_Parse_String},'<- 1')))}, silent=TRUE),'try-error'),1,0))")
      @writer.puts "rm(#{RinRuby_Parse_String})"
      if(result == [0])
        retVal = true
      else
        retVal = false
        raise ParseError, "Parse error - the R code provided is not assignable"
      end
      return retVal
    end

    # Locate R executable under Windows (uses registry unless cygwin)
    # @param [Boolean] cygwin Indicate whether using R under Cygwin or not.
    # @return [String] the path to R
    # @raise [RuntimeError] if R could not be found
    def find_R_on_windows(cygwin)
      path = '?'
      for root in [ 'HKEY_LOCAL_MACHINE', 'HKEY_CURRENT_USER' ]
        `reg query "#{root}\\Software\\R-core\\R" /v "InstallPath"`.split("\n").each do |line|
          next if(line !~ /^\s+InstallPath\s+REG_SZ\s+(.*)/)
          path = $1
          path.strip!
          break
        end
        break if(path != '?')
      end
      raise "Cannot locate R executable" if(path == '?')
      if(cygwin)
        path = `cygpath '#{path}'`
        path.strip!
        path.gsub!(' ', '\ ')
      else
        path.gsub!('\\', '/')
      end
      for hierarchy in [ 'bin', 'bin/i386', 'bin/x64' ]
        target = "#{path}/#{hierarchy}/Rterm.exe"
        if(File.exists?(target))
          return %Q<"#{target}">
        end
      end
      raise "Cannot locate R executable"
    end

    # Determine if R has been closed or not
    # @return [Boolean] indicating if it's closed or not
    def engineClosed?()
      return (@reader.closed? or @writer.closed? or @error.closed?)
    end

    # Actually close R streams
    def closeEngine()
      @reader.close() rescue false
      @writer.close() rescue false
      @error.close()  rescue false
    end
  end # class RinRuby
end ; end ; end # module BRL ; module Stats ; module R

# ------------------------------------------------------------------
# MAIN - run at load/require time
# ------------------------------------------------------------------

# Set the global "R" instance of RinRuby for convenience, unless already defined
unless(defined?(R))
  # R is an instance of RinRuby. If for some reason the user does not want R to be initialized
  # (to save system resources), then create a default value for R (e.g., <b>R=2</b> )
  #  in which case RinRuby will not overwrite the value of R.
  R = BRL::Stats::R::RinRuby.new
end

