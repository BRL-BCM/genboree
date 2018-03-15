
module BRL ; module Redmine ; module Tasks
  # Class and instance methods that help with Redmine task-helper class setup and
  #   initialization. Especially for tasks that want full access to Redmine & Plugin MVC
  #   so task code can operate somewhat like a Controller-Action.
  # @note Some of the key methods here run BEFORE Rails or the Redmine Application are
  #   initialized. So will not have access to the lib/, app/, plugins/*/lib/, plugins/*/app/ classes
  #   and modules [yet]. Thus this special library is available from BRL's Ruby library, and not
  #   part of Redmine or any plugin.
  module InitTaskHelper
    def self.included( includingClass )
      includingClass.send( :include, InitTaskHelperInstanceMethods )
      includingClass.extend( InitTaskHelperClassMethods)
    end

    module InitTaskHelperInstanceMethods
      # Ensure Task Helper has the expected instance variables available, just like Controller code assumes [after
      #   relevant before_filters of course].
      attr_reader :currRmUser, :rackEnv
      attr_reader :project, :projectId
      attr_reader :settingsRec, :settingsFields

      # A common need. Get the User object/record for Redmine login, and populate @currRmUser and
      #   the :currRmUser env key. Makes a fake Rack env available via @rackEnv (where normally see it)
      #   and there will be a placeholder 'async.callback' key within the env.
      # @note This module already ensures that 'env' is available as some Rails stuff expects; env() just exposes
      #   the aforementioned @rackEnv.
      # @param [String] login The Redmine/Genboree login. Typically this is the user the rake task will run
      #   as to do its work. Likely that use will need sufficient memberships, roles, and thus permissions to
      #   to various things.
      # @return [Hash] The @rackEnv object. But @currRmUser object will also be available, if found.
      def initUser( login )
        $stderr.debugPuts(__FILE__, __method__, 'DEBUG', "USER Init - make most Redmine things see #{login.inspect} as the current 'session' User (there is no actual session, but instance vars, User.current, and env will be set to see this User)")
        # Make similar to request => controller action
        @currRmUser      = User.find_by_login(login)
        User.current     = @currRmUser
        @rackEnv = initRackEnv()
        @rackEnv[:currRmUser] = @currRmUser
      end

      # Makes a fake Rack env available via @rackEnv (where normally see it)
      #   and there will be a placeholder 'async.callback' key within the env.
      def initRackEnv()
        @rackEnv ||= {}
        unless( @rackEnv['action_dispatch.request_id'] )
          @rackEnv['action_dispatch.request_id'] = "534890612862#{"%03i" % rand(1000)}"
        end
        unless( @rackEnv['async.callback'] )
          @rackEnv['async.callback'] = Proc.new { |*args|
            $stderr.puts "\n\nMOCK Rack 'async.callback'. Args: #{args.inspect}\n\n"
          }
        end
        return @rackEnv
      end

      def env()
        @rackEnv || initRackEnv()
      end

      # Convenience function. Given a simple array of Symboles, run their "before_filter" methods. Similar
      #   to before_filter in a Controller, but run by your Task Helper code at the appropriate time--typically
      #   in initialize() but after self.initRedmineMVC() !
      # @note Only simple symbol-based filters are supported. Real Rails Controllers support filter code blocks
      #   and more complex scenarios; this does not.
      # @params [Array<Symbol>] filterSyms The array of simple before_filter symbols to run, in order provided
      def runBeforeFilters( filterSyms=[] )
        $stderr.debugPuts(__FILE__, __method__, 'DEBUG', "BEFORE_FILTERS - About to run some basic before_filter methods at a similar early stage like Rails before_filter() functionality arranges during an http request. Methods to call: #{filterSyms.inspect}")
        filterSyms.each { |filterSym|
          self.send( filterSym )
        }
      end
    end

    module InitTaskHelperClassMethods
      # A common need. Safely initialize the Redmine Rails application so it makes all
      #   MVC available, but without interferring with normal initialization during
      #   Redmine boot-up nor Redmine's own tasks.
      # @note Requires a dedicated RAILS_ENV with the suffix "-rake" to encourage configuration
      #   of a suitable environment for running offline/automated rake tasks. This prevents
      #   logging to the typical 'production' or 'development' log files, which is what will
      #   happen once we RedmineApp::Application.initialize!
      # @param [Array<Class>] helperModules A list of module, generally plugin app/helper/ classes,
      #   that you want your Task Helper to include. Just like you want your Controllers to include
      #   some helpers they need. Convenience method; probably you could code these in your Task
      #   Helper as "self.include( CLASS )" after calling this method.
      def initRedmineMVC( helperModules=[] )
        # We use a specific new rails environment 'prod-rake' which is largely
        #   like the production env but redirects the logging to use STDERR (not projection.log!)
        #   and a few other little tweaks. It also helps give safe access to the full Redmine + Plugins MVC code.
        raise "\n\nERROR:  You are using an application environment (RAILS_ENV=#{Rails.env.to_s.inspect}), not one dedicated for offline or automated rake tasks. You can only use MapMaker in a dedicated rake-oriented environment, not one of the environments your Rails app normally uses.\n\n" unless( Rails.env.to_s =~ /-rake$/ )
        # Ensure Redmine is initialized. This will discover and load your various Redmine and Plugin MVC code.
        # By initializing the Redmine application, you cause it to add your plugin dirs to $LOAD_PATH
        #   and configure the Rails autoloader to see your plugin code in addition to Redmine code. So
        #   classes, modules etc will be automatically found.
        # @note We altered RedmineApp::Application to implement the Rails 4 "initialized?" method. Else such a
        #   check is impossible.
        $stderr.debugPuts(__FILE__, __method__, 'DEBUG', "MVC Init - About to RedmineApp::Application.initialize!")
        RedmineApp::Application.initialize! unless( Rails.application.initialized? )
        # By doing this include at the last moment (during instantiation) we hide this Redmine app initializing
        #   and the including for a plugin Helper from other Redmine tasks that
        #   do NOT use Redmine MVC classes and would get irritated (break) if we called initialize! at all. Also we
        #   ensure it's not done during regular Redmine boot as a side effect of examining
        #   and loading task files (which it would if it were outside of method invocation)
        helperModules.each { |helperModule|
          $stderr.debugPuts(__FILE__, __method__, 'DEBUG', "MVC Init - Including helper module #{helperModule.inspect} into #{self.inspect}")
          include helperModule
        }
        include Redmine::I18n         # Now have access to l() localization method like in views (but from controller-like Task Helper)
        $stderr.debugPuts(__FILE__, __method__, 'DEBUG', "MVC Init - Initialized redmine app and included some key helper modules")
      end
    end
  end
end ; end ; end # module BRL ; module Redmine ; module Tasks
