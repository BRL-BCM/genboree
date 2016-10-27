require 'brl/genboree/abstract/resources/annotationFile'
require 'brl/genboree/rest/em/deferrableBodies/deferrableDelegateBody'

module BRL ; module Genboree ; module REST ; module EM ; module DeferrableBodies
  # All this does is add a check that incoming delegate is specifically an AnnotationFile object.
  #   Turns out the generic DeferrableDelegateBody can handle this, as-is.
  class DeferrableTrackAnnosBody < DeferrableDelegateBody

    # @return [Array<Symbol>] Array of events fired. Add via addListener(event, listenerProc). Really just here to document:
    #   * :sentChunk => called after a chunk is actively sent or passibly yielded up the chain; can be called MANY times
    #   * :finish => called after class's finish() ; the last event fired
    attr_reader :events

    # AUGMENT. Include a super(opts) call.
    def initialize(opts)
      super(opts)
      raise ArgumentError, "ERROR: Not an instance of BRL::Genboree::Abstract::Resources::AnnotationFile : #{@delegate.inspect}" unless(@delegate.is_a?(BRL::Genboree::Abstract::Resources::AnnotationFile))
    end

    # AUGMENT. Include a super() call
    # Immediately (synchronously, this tick) perform finish/clean-up (i/o & memory clean up). Generally immediate, not async.
    def finish()
      super()
      return
    end
  end
end ; end ; end ; end ; end
