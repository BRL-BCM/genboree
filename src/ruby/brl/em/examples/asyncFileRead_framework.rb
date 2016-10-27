
require 'eventmachine'

module SimpleAsyncFileReader
  # OPTIONAL: Extra args (context etc) can be passed from EM.watch() after 1st two core args.
  #   If you do this, then you can define an initialize; else, no need for initialize.
  def initialize(*aa)
    $stderr.puts "STATUS: CUSTOM CONSTRUCTOR CALLED BY EM: aa: #{aa.inspect}"
  end

  # This is called once EM has mixed in some stuff to this class, instantiated it, and is ready to use it.
  def post_init()
    $stderr.puts "STATUS: EM INITIALIZED Handler."
  end

  # Watches for when the IO becomes readable. For sockets it will do this as data becomes available.
  #   In our case, we have a file so we trigger "is readable" event to get things moving (see run() below).
  #   Note: EM will call this every so often. You do a bit of work (read bit from IO) and return, it calls you again, repeat.
  def notify_readable()
    # Read some data (here a line for illustration)
    line = @io.readline rescue nil
    $stderr.puts "#{Time.now} Read a line: #{line.inspect}"

    # ... Do stuff with line/chunk of data you read (but don't do TOO much)...

    # Have we reached the end? If so we need to trigger correct watching-shutdown
    #   And ensure we do our own clean up of stuff!
    if(line == "\r\n" or line.nil?)
      $stderr.puts "           -> Reached END OF DATA. Stop watching via detach() method"
      # detach returns the file descriptor number (fd == @io.fileno)
      detach()
    end

    # Prove async file reading via some add_timer calls
    prove()
  rescue => err # begin-rescue shorthand for this method
    # Look we need to be really sure we shutdown properly if possible. AND, separately that we clean up our stuff.
    $stderr.puts "EXCEPTION IN NOTIFY: #{err.class} => #{err.message.inspect}"
    detach() rescue nil
    clean() rescue nil
  end

  def unbind()
    $stderr.puts "STATUS: Our unbind() callback called."
    clean()
    $stderr.puts "  STOPPING WATCH on #{@io.inspect} ; called clean up"
  end

  # NOT EM API methods:
  def clean()
    unless(@io.nil? or (@io.closed? rescue nil))
      @io.close rescue nil
    end
  end

  def prove()
    self.notify_readable = false
    EM.add_timer(5) {
      self.notify_readable = true
    }

    1.upto(3) { |ii|
      EM.add_timer(ii) {
        unless(notify_readable?)
          $stderr.puts "   -> PAUSED (#{ii.inspect}). But here we are, doing things..."
        end
      }
    }
  end
end

EventMachine.run {
  # Some extra args we can pass in to our Handler(see initialize())
  extraArg1 = "Need this info"
  extraArg2 = { :setting1 => 10, :setting2 => 20 }
  # Get the IO to watch:
  fh = File.open( File.expand_path( "~/.bashrc") )
  # Arrange for EM to help us "watch" this IO.
  #  First arg is the IO to watch, then a Handler class that implements key EM API methods, then 0+ extra args for your construction [optional]
  asyncReader = EM.watch(fh, SimpleAsyncFileReader, extraArg1, extraArg2)
  $stderr.puts "STATUS: Got back an initialized IO Handler instance:\n    #{asyncReader.inspect}"
  # Because it's a normal file that exists (not socket that will become readable), manually trigger our reading flow:
  asyncReader.notify_readable = true
}
