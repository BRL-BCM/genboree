require 'brl/util/util'

module GenericHelpers
  module BeforeFiltersHelper

    # ----------------------------------------------------------------
    # BEFORE_FILTERS - useful before_filter methods for your controller
    # ----------------------------------------------------------------

    # Popular the @urlMount variable with this Redmine's mount point (first dir in path)
    def getKbMount()
      @redmineMount = @kbMount = @urlMount = RedmineApp::Application.routes.default_scope[:path].to_s.gsub(/'/, "\\\\'").gsub(/\n/, ' ') ;
      #$stderr.debugPuts(__FILE__, __method__, 'DEBUG', "generic getKbMount has set @redmineMount, @kbMount, @urlMount to #{@redmineMount.inspect}")
    end
    alias_method(:redmineMount, :getKbMount)
    alias_method(:getUrlMount, :getUrlMount)

    # Authorize the user for the requested action. In addition to regular checks, allow if project is public.
    #   Always allow members through
    def authorize_with_public_project(ctrl = params[:controller], action = params[:action], global = false)
      #$stderr.debugPuts(__FILE__, __method__, 'DEBUG', "ctrlr: #{ctrl.inspect} ;;; action: #{action.inspect} ;;; global: #{global.inspect} ;;; project: #{@project.inspect}")
      # Usual check (from Redmine's ApplicationController#authorize) based on project & permissions
      # @todo Temp TRY to use @currRmUser and fallback on async-unsafe User.current global. The latter must GO AWAY after plugins updated.
      currUsr = ( @currRmUser or User.current )
      allowed = currUsr.allowed_to?({:controller => ctrl, :action => action}, @project || @projects, :global => global)
      if(allowed or @project.is_public? or currUsr.member_of?(@project)) # Either user allowed or project is public
        true
      else # Not allowed, determine appropriate response.
        if(@project && @project.archived?)
          render_403 :message => :notice_not_authorized_archived_project
        else
          deny_access
        end
      end
    end
    
    # Used in cases where we want the users to be redirected to login page.
    def redirect_anon_to_login( backurl=nil )
      if(User.current.anonymous? or User.current.login.nil? or User.current.login == "")
        kbMount = RedmineApp::Application.routes.default_scope[:path].to_s
        redirectUrl = "#{kbMount}/login?"
        backurl = "#{env["rack.url_scheme"]}://#{request.host}#{request.fullpath}" unless(backurl)
        #$stderr.puts "rack.url_scheme: #{env["rack.url_scheme"]}"
        redirectUrl << "back_url=#{CGI.escape(backurl)}"
        redirect_to redirectUrl    
      end
    end
    
    def authorize_via_perms_only()
      allowed = userAllowedByControllerAction?
      if( allowed) 
        true
      else # Not allowed, determine appropriate response.
        if(@project && @project.archived?)
          render_403 :message => :notice_not_authorized_archived_project
        else
          deny_access
        end
      end
    end


    # Strip the original url trailing slashes and redirect to the stripped url
    def trailing_slash_orig_url_redirect
      if(request.original_url =~ /(.*)\/$/)
        redirect_to $1
      end
    end

    def is_client_request_https?()
      $stderr.debugPuts(__FILE__, __method__, 'DEBUG', "Enter.")
      retVal = false
      if( request )
        $stderr.debugPuts(__FILE__, __method__, 'DEBUG', "Have request.")
        if( request.headers.is_a?(Hash) )
          $stderr.debugPuts(__FILE__, __method__, 'DEBUG', "Have request headers.")
          # Then we really want to assess the distal (downstream) client connection, probably to our incoming proxy
          schemeToAssess = request.headers['HTTP_X_CLIENT_REQUEST_SCHEME']
          $stderr.debugPuts(__FILE__, __method__, 'DEBUG', "X-Client-Request-Scheme header is #{schemeToAssess.inspect}")
          if( schemeToAssess.blank? ) # Else fall back on proximal/immediate scheme, and assess it.
            schemeToAssess = request.scheme
          end

          $stderr.debugPuts(__FILE__, __method__, 'DEBUG', "Regardless, scheme to assess is #{schemeToAssess.inspect}")

          if(schemeToAssess)
            retVal = ( schemeToAssess.to_s.downcase == 'https' )

            $stderr.debugPuts(__FILE__, __method__, 'DEBUG', "is scheme https? #{retVal.inspect}")
          end
        end
      end

      $stderr.debugPuts(__FILE__, __method__, 'DEBUG', "Returning retVal=#{retVal.inspect}")
      return retVal
    end

    def reject_unless_client_request_https( )
      $stderr.debugPuts(__FILE__, __method__, 'DEBUG', "Enter.")
      if( is_client_request_https? )
        true
      else
        render_403 :message => 'HTTPS is required for security'
      end
    end
  end
end
