
# Illustrative (and ~test) Controller based on GbDb::GbUser lib usage
class GenboreeGenericUiTestsController < ApplicationController
  # So we can use renderToClient() and usual Rails MVC approaches.
  # * To use these async, will need to init the rack info via initRackEnv() first.
  include GbMixin::AsyncRenderHelper

  # Run standard hooks for gathering typical context, user, and settings info
  before_filter :find_project

  unloadable

  # Indicate layout to use for page. Here, the application's (Redmine's) base layout
  layout 'base'

  # A "show" type controller action. Wouldn't do any updating here.
  # * Of course there should be a matching app/views/{controller}/show_test1.html.erb
  def show_test1()
    initRackEnv( env ) # See comment above
    controller = self
    GbDb::GbUser.byLogin(env, @currRmUser.login ) { |rs|
      if( rs[:obj] ) # Success result
        @gbUser = rs[:obj]
        @gbErr = nil
        # GbUser objects also mixin AsyncRenderHelper, so can call using that
        @gbUser.renderToClient( controller ) # Default view (one matching the action of course) and status, etc. But for another option, see code below
      else # Coun't even get the record??
        @gbUser = nil
        @gbErr = rs[:err] rescue nil
        # Here we have no GbUser object but still want to use renderToClient() to show USER something about error!
        # - Because we mixed in AsyncRenderHelper to this class, and initialized it appropriately above (via initRackEnv())
        #   We should be able to call this as an instance method of this controller.
        renderToClient( controller, :gb_user_err, 418 ) # Different view
      end
    }
    throw :async
  end

  def show_fail1()
    initRackEnv( env )
    GbDb::GbUser.byLogin(env, 'no_such_user_oops') { |rs|
      #if( rs[:obj] ) # BUG: we DON'T CHECK FIRST, so as to make a nasty exception
        @gbUser = rs[:obj]
        @gbErr = nil
        # GbUser objects also mixin AsyncRenderHelper, so can call using that
        # - But there is no user in rs[:obj]. So the next line will be a "no such method renderToClient for nil" kind of exception
        # - Since not if-else checks & handled AND no begin-rescue for contextual handling of errors in nice way, library will
        #   rescue this and handle it its own way.
        @gbUser.renderToClient( controller ) # Default view (one matching the action of course) and status, etc. But for another option, see code below
    }
    throw :async
  end

  # A "update" type controller action. Bit more complicated, not only because of updating
  #   but because can just be loading page OR submitting form with changes!
  # * Again, there is a app/views/{controller}/update_inst1.html.erb
  def update_inst1()
    # Get a valid GbUser backed by table record
    initRackEnv( env ) # See comment above
    controller = self
    GbDb::GbUser.byLogin(env, @currRmUser.login ) { |rs|
      if( rs[:obj] ) # The success result
        @gbUser = rs[:obj]
        @gbErr = nil
        # If POST, make the change
        if( request.post? )
          @gbUser.institutionUpdate( @gbUser.login, params['inst'] ) { |countRs|
            @rowCount = countRs[:count]
            @gbErr = countRs[:err]
            # See if we just did an update of table.
            if( @rowCount )
              # See if it looks like successful/expected update or something unexpected (but without error)
              # * Layout knows what to do when flash is set. Nice application-wide standard, rather than per-view flash messages.
              if( @rowCount > 0 and @rowCount < 2 )
                flash[:notice] = 'Institution successfully updated.'
              else
                flash[:error] = "Institution update gave unexpected results. (System raised no errors, but says updated #{@rowCount.inspect} rows rather than expected number.)"
              end
              # Render form...which will end up showing the new record info automatically
              renderToClient( controller, params['action'] )
            else # Didn't get a count, something bad happened.
              unless(@gbErr)
                @gbErr = RuntimeError.new( "ERROR: update failed to return a row-count, but no exception available in :err to see what went wrong!")
                @gbErr.set_backtrace( [ "#{__FILE__}:#{__LINE__}" ] + caller )
              end
              renderToClient( controller, :gb_user_err, 418 )
            end
          }
        else # GET, probably, so nothing to do...View will just show the form, pre-fillted with current institution
          @rowCount = nil
          renderToClient( controller, params['action'] )
        end
      else # Couldn't even get the record?
        @gbUser = nil
        @gbErr = rs[:err] rescue nil
        # Here we have no GbUser object but still want to use renderToClient() to show USER something about error!
        # - Because we mixed in AsyncRenderHelper to this class, and initialized it appropriately above (via initRackEnv())
        #   We should be able to call this as an instance method of this controller.
        renderToClient( controller, :gb_user_err, 418 ) # Different view
      end
    }
    throw :async
  end

  # This action simply triggers the sending of a custom email to a user. Done properly.
  # - Normally this action would do something more useful first and then pass relevant
  #   info to the custom mailer action so it can prep and send an appropriate email.
  # - Here we mock this by just prepping some silly args.
  def custom_email1()
    user = @currRmUser
    if( user.type == 'AnonymousUser')
      flash[:error] = l(:gb_generic_custom_email_refuse)
    else
      anArg = rand( 1_000 )
      GbIllustrativeMailer.custom_mail_notice( user, anArg ).deliver
      flash[:notice] = l(:gb_generic_custom_email_ok, user.firstname)
    end
  end

  # ------------------------------------------------------------------
  # PRIVATE METHODS
  # ------------------------------------------------------------------

  private

end
