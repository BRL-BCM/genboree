require 'brl/util/util'

module GenericHelpers
  module BeforeFiltersHelper

    # ----------------------------------------------------------------
    # BEFORE_FILTERS - useful before_filter methods for your controller
    # ----------------------------------------------------------------

    # Authorize the user for the requested action. In addition to regular checks, allow if project is public.
    #   Always allow members through
    def authorize_with_public_project(ctrl = params[:controller], action = params[:action], global = false)
      $stderr.debugPuts(__FILE__, __method__, 'DEBUG', "ctrlr: #{ctrl.inspect} ;;; action: #{action.inspect} ;;; global: #{global.inspect} ;;; project: #{@project.inspect}")
      # Usual check (from Redmine's ApplicationController#authorize) based on project & permissions
      allowed = User.current.allowed_to?({:controller => ctrl, :action => action}, @project || @projects, :global => global)
      if(allowed or @project.is_public? or User.current.member_of?(@project)) # Either user allowed or project is public
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
  end
end
