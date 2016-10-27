require 'thread'
require 'date'
require 'time'
require 'i18n'
require 'i18n/backend'
require 'i18n/backend/simple'
require 'active_support'
require 'active_support/multibyte/unicode'
require 'active_support/inflector/transliterate'

module BRL
  class ActiveSupport
    class << self
      attr_accessor :restoreJsonMethodsLock
      BRL::ActiveSupport.restoreJsonMethodsLock = Mutex.new
    end

    # Attempt to restore the json gem's json method since activesupport probably overwrote them.
    def self.restoreJsonMethods()
      BRL::ActiveSupport.restoreJsonMethodsLock.synchronize {
        #--
        # STRIP ActiveSupport's crappy-ass to_json manually for certain classes, allowing
        # the JSON library's default method (added to Object...basically a self.to_s.to_json to be the code run).
        # Otherwise can get errors when converting an instance of one of these.
        [ Fixnum, Symbol, Date, DateTime, Enumerable, Numeric, Regexp, Time, Hash, Array ].each { |klass|
          klass.class_eval {
            klass.instance_methods(false).each { |meth|
              remove_method(meth) if(meth.to_s == 'to_json')
            }
          }
        }
        if(defined?(JSON) and defined?(JSON::JSON_LOADED)) # then json library already loaded, we're gonna need to force the reload due to activesupport nuking our to_json methods
          oldVerbose, $VERBOSE = $VERBOSE, nil
          begin
            load 'json/ext.rb'  # won't work if was already loaded
            # NOTE: this converts
            #          { :foo => [ :bar, 10 ] }  to JSON:
            #          "{\"foo\":[{\"s\":\"bar\",\"json_class\":\"Symbol\"},10]}"
            # Which corrupts the json, and can break javascript libraries.
            #load 'json/add/core.rb'
            begin
              #load 'json/add/rails.rb'
            rescue ScriptError => err # allow this to silently fail (newer envs like RedmineKB ones don't have nor need this)
            end
            load 'brl/activeSupport/time.rb'
          rescue Exception => err
            $stderr.puts "LOAD ERROR: could not load json/ext after activesupport for some reason. Error was:\n  #{err.message}\n#{err.backtrace.join("\n")}"
            require 'json/ext' # attempt as a back up
            #require 'json/add/core'
            begin
              #require 'json/add/rails.rb'
            rescue ScriptError => err # allow this to silently fail (newer envs like RedmineKB ones don't have nor need this)
            end
            require 'brl/activeSupport/time'
          end
          $VERBOSE = oldVerbose
        else # first time seeming json, do normal require
          require 'json/ext'
          #require 'json/add/core'
            begin
              #require 'json/add/rails.rb'
            rescue ScriptError => err # allow this to silently fail (newer envs like RedmineKB ones don't have nor need this)
            end
          require 'brl/activeSupport/time'
        end
      }
    end
    
    def self.requireCoreExt(extReqPaths=[])
      BRL::ActiveSupport.restoreJsonMethodsLock.synchronize {
        extReqPaths.each { |reqPath|
          require reqPath
        }
      }
    end
  end
end

BRL::ActiveSupport.restoreJsonMethods()
