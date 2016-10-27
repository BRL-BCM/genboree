require 'eventmachine'
require 'brl/util/util'

module BRL ; module Genboree ; module REST ; module EM ; module Events ; module EventNotifier

  # Add a listener (Proc) to an event. Currently the only event is :finish.
  # @param [Symbol] event A supported event Symbol. Currently just :finish notifies its listeners and
  #   is called at the beginning of the finish() method; so it's more :finish_start, hah.
  # @param [Proc] listener A {Proc} which will be given 2 args: @event@ (Symbol) and this @AbstractDeferrableBody@ instance (i.e this object).
  def addListener(event, listener)
    unless(@listeners)
      @listeners = Hash.new { |hh,kk| hh[kk] = [] }
    end
    @listeners[event] << listener
  end

  # Used by including classes to notify the list of listeners for the event. Each listener is notified tick-by-tick.
  #   Use this if you'r overriding infrastructure (like the schedule* methods) and want to allow event notifications fro
  #   different phases of the response.
  def notify(event)
    if(@listeners)
      eventListeners = @listeners[event]
      if(eventListeners.is_a?(Array) and !eventListeners.empty?)
        ::EM.next_tick {
          scheduleNotices(event, 0)
        }
      end
    end
  end

  # Can be used by an including class to clean-up the listeners Hash-of-Arrays
  def clearListeners()
    if(@listeners)
      @listeners.each_key { |event|
        eventListeners = @listeners[event]
        if(eventListeners)
          eventListeners.clear
        end
      }
      @listeners.clear
      @listeners = nil
    end
  rescue => err
    $stderr.debugPuts(__FILE__, __method__, "ERROR", "RECOVERED: Unexpected error clearing listeners: #{err.class} => #{err.message.inspect} ; Backtrace:\n#{err.backtrace.join("\n")}")
  end

  private

  # EM::Iterator would be good here, if it were available.
  # This a standard iterate-over-list-processing-one-per-tick pattern.
  def scheduleNotices(event, idx)
    if(@listeners)
      eventListeners = @listeners[event]
      if(eventListeners.is_a?(Array))
        listener = eventListeners[idx]
        if(listener) # else we walked off the end of eventListeners and there are no more (done)
          begin # Protect vs badly written listener Procs
            listener.call(event, self)
          rescue => err
            $stderr.debugPuts(__FILE__, __method__, "BUG", "A listener Proc on the #{event.inspect} event is poorly written and raised a #{err.class}.\n  * Message: #{err.message.inspect}\n  * Trace:\n#{err.backtrace.join("\n")}")
          ensure # no inf loops!
            idx += 1
            ::EM.next_tick {
              scheduleNotices(event, idx)
            }
          end
        end
      end
    end
    return
  end
end ; end ; end ; end ; end ; end # module BRL ; module Genboree ; module REST ; module EM ; module Events ; module EventNotifier
