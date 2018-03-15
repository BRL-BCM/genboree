require_dependency 'application_controller'

module GenboreeGenericApplicationControllerPatch
  def self.included(base) # :nodoc:
    base.send(:include, InstanceMethods)

    #$stderr.puts "SPIKING IN AN 'attr_accessor :currRmUser to #{base.inspect}'"
    base.send( :attr_accessor, :currRmUser )

    base.class_eval do
      alias_method_chain :user_setup, :local_current_user
      alias_method_chain :logged_user=, :local_current_user
      alias_method_chain :find_current_user, :smarter_api_decision
      alias_method_chain :start_user_session, :force_make_csrf_token
    end
  end

  module InstanceMethods
    # We are intercepting the ApplicationController#user_setup method.
    # - we implement a slgihtly changed version than original method
    # - original method NOT CALLED but available as user_setup_without_local_current_user
    def user_setup_with_local_current_user()
      #$stderr.debugPuts(__FILE__, __method__, 'REDMINE ALT', "[#{request.path.inspect}] USING alternative implementation of Redmine's ApplicationController#user_setup. param auth token: #{params[:authenticity_token].inspect rescue 'N/A'} ; session (#{session.object_id}):\n\n#{session.inspect}\n\n")
      # Check the settings cache for each request
      Setting.check_cache
      # Find the current user
      @currRmUser = find_current_user
      if( @currRmUser.nil? ) # not-logged in user....@currRmUser forced to anonymous in this case
        #$stderr.puts "    REDMINE ALT: USER NOT LOGGED IN? find_current_user gave back nil. FORCING @currRmUser to ANONYMOUS."
        @currRmUser = User.anonymous
      #else
        #$stderr.puts "    REDMINE ALT: USER is LOGGED IN. find_current_user gave back non-nil."
      end
      #$stderr.puts "    REDMINE ALT: Almost done ALTERED user_setup method." #" Do we have env() ?\n\n#{env.inspect}\n\n"
      env[:currRmUser] = @currRmUser
      User.current = find_current_user
      #$stderr.puts "    REDMINE ALT: About to leave. session:\n\n#{session.inspect}\n\n"
      logger.info("  Current user: " + (User.current.logged? ? "#{User.current.login} (id=#{User.current.id})" : "anonymous")) if logger
    end

    # We are intercepting the ApplicationController#logged_user method.
    # - we implement a slightly changed version than original method
    # - original method NOT CALLED but available as logged_user_without_local_current_user
    def logged_user_with_local_current_user=(user)
      #$stderr.debugPuts(__FILE__, __method__, 'REDMINE ALT', "[#{request.path.inspect}] USING alternative implementation of Redmine's ApplicationController#logged_user= .. Params token: #{params[:authenticity_token].inspect rescue 'N/A'} ; session (#{session.object_id}):\n\n#{session.inspect}\n\n")
      #$stderr.puts "    REDMINE ALT: About to reset_session"
      reset_session
      #$stderr.puts "    REDMINE ALT: Done reset_session"

      if user && user.is_a?(User)
        User.current = env[:currRmUser] = @currRmUser = user
        #$stderr.puts "    REDMINE ALT: user is_a User. About to start_user_session and return"
        start_user_session(user)
      else
        #$stderr.puts "    REDMINE ALT: user is not a User. Employing Redmine's User.anonymous. session (#{session.object_id}):\n\n#{session.inspect}\n\n"
        User.current = env[:currRmUser] = @currRmUser = User.anonymous
      end
    end

    # Original Redmine find_current_user implementation is not very smart w.r.t. deciding whether
    #   the request is a Redmine API call or not. It treats ANY request for .json or .xml formats/extensions
    #   as being Redmine API requests that need to be routed through the Redmine API engine, which uses a
    #   DSL and .{format}.rsb templates. This prevents plugins from having their own separate .json.erb and/or
    #   .xml.erb plugin-specific JSON/XML production (i.e. no intention of adding to Redmine API or using .rsb).
    # This is because original Redmine code uses ONLY api_request? to make the decision. But it doesn't actually
    #   check that. It checks if format is a known Redmine API format. There are other conditions needed for the
    #   request to be a valid Redmine API request. And Redmine code checks those...but only after using api_request?
    #   blindly basing things on .json or .xml. Silly.
    # The fix, to allow plugins to have their own .json.erb or .xml.erb WITHOUT colliding with Redmine API or even
    #   optionally extend the Redmine API properly (as some plugins do), is to check all 3 conditions for an Redmine
    #   API request and handling the request either (A) normally using plugin MVC and {format}.erb templates or (B)
    #   as Redmine API using their API infrastructure classes, methods, custom renderer etc etc.
    # 1. api_request? - Does it look like it might be a Redmine API request. AND
    # 2. Setting.rest_api_enabled? - Does this Redmine installation even HAVE the API enabled (possibly could remove this condition). AND
    # 3. accept_api_auth? - HA! Does this controller-action specifically indicate that it can be used for Redmine API
    #    type requests? If not, why don't we handle the request as a regular Rails MVC request rather than being a dick??????? Duh!
    def find_current_user_with_smarter_api_decision
      user = nil
      #$stderr.debugPuts(__FILE__, __method__, 'REDMINE ALT', "[#{request.path.inspect}] USING alternative find_current_user. Is this api_request? #{(api_request? && Setting.rest_api_enabled? && accept_api_auth?).inspect}. #{params[:authenticity_token].inspect rescue 'N/A'} ; session (#{session.object_id}):\n\n#{session.inspect}\n\n")
      if api_request? && Setting.rest_api_enabled? && accept_api_auth?
        #$stderr.puts "    REDMINE ALT: (1) yes looks like api (format is json or xml) AND (2) rest api is enabled AND (3) we're going to accept api authentication for this controller-action"
        if (key = api_key_from_request)
          # Use API key
          user = User.find_by_api_key(key)
          #$stderr.puts "    REDMINE ALT: Found user via api key from request."
        else
          # HTTP Basic, either username/password or API key/random
          authenticate_with_http_basic do |username, password|
            #$stderr.puts "    REDMINE ALT: Looking for user via http_basic authentication"
            user = User.try_to_login(username, password) || User.find_by_api_key(username)
          end
          if user && user.must_change_password?
            #$stderr.puts "    REDMINE ALT: User marked as must change password"
            render_error :message => 'You must change your password', :status => 403
            return
          end
        end
        # Switch user if requested by an admin user
        if user && user.admin? && (username = api_switch_user_from_request)
          #$stderr.puts "    REDMINE ALT: Special dmin switch user functionality employed"
          su = User.find_by_login(username)
          if su && su.active?
            logger.info("  User switched by: #{user.login} (id=#{user.id})") if logger
            user = su
          else
            render_error :message => 'Invalid X-Redmine-Switch-User header', :status => 412
          end
        end
      else
        #$stderr.puts "    REDMINE ALT: NO, it's not a formal Redmine-style API call because at least one of the following is false: (1) looks like api request (format is json or xml) [#{api_request?.inspect}] ; (2) rest api is enabled [#{Setting.rest_api_enabled.inspect}] ; (3) we're going to accept api authentication for this controller-action [#{accept_api_auth?.inspect}]"
        if session[:user_id]
          # existing session
          #$stderr.puts "    REDMINE_ALT(#{__method__}): we have a user session (:user_id available in session)."
          user = (User.active.find(session[:user_id]) rescue nil)
          #$stderr.puts "    REDMINE_ALT(#{__method__}): ...and found a non-nil user for session? #{user.nil? ? false : true}"
        elsif autologin_user = try_to_autologin
          #$stderr.puts "    REDMINE_ALT(#{__method__}): wants to try_to_autologin user"
          user = autologin_user
          #$stderr.puts "    REDMINE_ALT(#{__method__}): autologin_user have non-nil user? #{user.nil ? false :true }"
        elsif params[:format] == 'atom' && params[:key] && request.get? && accept_rss_auth?
          #$stderr.puts "    REDMINE_ALT(#{__method__}): thinks this is an ATOM/RSS feed request!!"
          # RSS key authentication does not start a session
          user = User.find_by_rss_key(params[:key])
        end
      end
      #$stderr.puts "    REDMINE_ALT(#{__method__}): By the end of #{__method__} user is:\n\n#{user.inspect}\n\n session (#{session.object_id}):\n\n#{session.inspect}\n\n}"
      user
    end
  end

  # This patched/shimmed version of Redmine's start_user_session pre-generates a CSRF token
  #   (anti form-forgery authenticity token) for the session to use.
  # Normally generation of the token is done "just in time" by View code employing Rails' form_tag which inserts
  #   two hidden <input> tags one of which includes the token so it's submitted along with the form or by csrf_meta_tag
  #   which puts the token info into a couple of <meta> tags in a very similar way. These methods also automatically add
  #   the token to the session, so it will be accepted when the form is submitted. Under regular Rails processing (sync)
  #   when the View does this "JIT" that altered session state is saved/committed when Rails' request tear-down code is
  #   run (i.e. after your View is done but before Rails actually replies to client through Rack or whatever).
  # HOWEVER, our async rendering BYPASSES that Rails tear-down which would save the "JIT" generated CSRF token in the session!!
  #   It's added to the in-RAM session object but not serialized nor persisted in the session store [there are various session
  #   stores that can be used; we're likely using default of cookie-store]! So the next request coming in--perhaps a POST that
  #   MUST have provide the anti-forgery token--gets rejected. That request has the correct token, the one that was generated
  #   "JIT", but because it wasn't saved in the session due to async bypass of whatever magic session-saving Rails does, the
  #   request was rejected.
  # We saw this inappropriately rejected POST in VBR and Patho Calc. In VBR the controller-action that shows a specific saved
  #   result renders the page View *async*. It was JIT generated the csrf token, but that was not saved in the session due to
  #   async as explained above. Once page loads in browser, it immediately does an Ajax POST of the search criteria associated with
  #   the Saved Result to update the cou nt of matching samples which is shown on the page. This POST was failing because
  #   CSRF token was present but not in the session...so clearly it didn't belong to the session (oops).
  # To solve this, we noted that the CSRF token persists with the session and if present in the session then any form_tag or
  #   csrf_meta_tag calls will use it from the session (if not, they create it and put it in the session...relying on Rails
  #   to save/commit the session at the end of the request). So we alter Redmine start_user_session to pre-generate the
  #   CSRF token and rely on the fact that start_user_session is used in sync/normal Rails flow...mainly/only when
  #   user logs into Redmine using the Redmine user-password form, for example.
  def start_user_session_with_force_make_csrf_token(user)
    #$stderr.debugPuts(__FILE__, __method__, 'REDMINE ALT', "Alternative start_user_session. self.object_id: #{self.object_id} ; controller.object_id: #{controller.object_id rescue 'N/A'} ; session (#{session.object_id}):\n\n#{session.inspect}\n\n")

    # Call original Redmine method which sets up the Redmine/application session info.
    start_user_session_without_force_make_csrf_token(user)

    #$stderr.debugPuts(__FILE__, __method__, 'SESSION - BEFORE MAKE CSRF', "Called original start_user_session. Now make CSRF token for session. self.object_id: #{self.object_id} ; controller.object_id: #{controller.object_id rescue 'N/A'} ; session (#{session.object_id}):\n\n#{session.inspect}\n\n")

    # Pre-generate a "_csrf_token" value for this session, rather than waiting for some View to create it the first time
    #   (via form_tag or csrf_meta_tag or similar) and running the risk of the altered session NOT BEING SAVED
    #   because rendering is done ASYNC and  thus BYPASSES regular rails request tear-down...including saving/committing
    #   altered session state (in our case, probably default of cookie-store, but kind of doesn't matter)
    form_authenticity_token()

    #$stderr.debugPuts(__FILE__, __method__, 'SESSION - AFTER MAKE NEW CSRF', "About to renderToClient. self.object_id: #{self.object_id} ; controller.object_id: #{controller.object_id rescue 'N/A'} ; session (#{session.object_id}):\n\n#{session.inspect}\n\n")

    true # original method returns either something akin to Time.now.to_i or string '1' ; so we return a true value, but likely no one cares.
  end
end

# Now apply our patched method to the core Redmine WikiController class via module include:
ApplicationController.send(:include, GenboreeGenericApplicationControllerPatch)
