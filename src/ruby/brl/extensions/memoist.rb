require 'memoist'
require 'brl/extensions/object'

module Memoist
  module InstanceMethods

    # OVERRIDE original memoized_structrs to support memoization via the
    #   object-specific METACLASS rather than generic class shared by all objects.
    #   * This is useful/necessary if you are memoizing class-methods--or instance methods
    #     for which there is also a class-method since the memoist gem will not distinguish.
    #   * By memoizing via the METACLASS, you only affect the object's personal metaclass leaving
    #     the generic class unaffected. Since you have control over the life-span of the object
    #     (and thus its personal metaclass), but you don't have control over the life-span of the
    #     generic classes, this lets you memoize class-level methods even in long-running daemon
    #     processes; when the object goes away, so does the metaclass, and you didn't alter
    #     the generic class (which doesn't go away).
    #   * Also this lets you memoize instance methods while leaving class method of the same name
    #     unaffected (unmemoized). Consider:
    #     - object.class # => generic class shared by all objects of this class
    #     - object.metaclass # => personal class specific to object
    #     Thus, by memoizing at the metaclass level and not class level:
    #     - object.class.onlyInstanceMethodShouldBeMemoized( arg 1) # => always calls unmemoized class method
    #     - object.onlyInstanceMethodShouldBeMemoized( arg1 ) # => always calls memoized instance method
    #     This scenario is not possible if you memoize at the class level as normal.
    # So to support this interesting case, when it looks like memoization was NOT done at the generic class
    #   level (like normal & assumed), we assume that memoization was done at the metaclass level and use
    #   that as a fallback. If that fails, we just raise the original error since something else is going on.
    def memoized_structs(names)
      # ARJ: Typically the general Class instance will have all_memoized_structs.
      # But if you memoized ONLY this instance, via metaclass-level memoization, then ONLY the specific metaclass for this instance
      #   has all_memoized_structs. Maybe you did that to avoid memoizing class methods with same
      #   name as instance methods (ouch) or because you're in a long-running daemon and memoizing
      #   "forever" vs "life of request" is bad and "life of request" is best done via metaclass level memoizing.
      begin
        structs = self.class.all_memoized_structs
      rescue NoMethodError => nme
        structs = self.metaclass.all_memoized_structs rescue nil
        raise nme unless(structs)
      end

      return structs if names.empty?

      structs.select { |s| names.include?(s.memoized_method) }
    end
  end
end