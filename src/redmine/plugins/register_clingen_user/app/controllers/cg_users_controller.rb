class CgUsersController < ApplicationController

  unloadable

  layout 'clingen_bootstrap'

  before_filter  :find_project 
  before_filter  :set_controller_action, :project_specific_authorize
  before_filter  :set_project_settings
  before_filter  :set_host
  before_filter  :set_honor

  skip_before_filter :check_if_login_required
  skip_before_filter :verify_authenticity_token
  #accept_api_auth :show

  include GbMixin::AsyncRenderHelper
  include CgUsersHelper

  def new
    # Declare empty User information
    @user_info = {
      "user_id" => "", 
      "e-mail" => "",
      "password" => "",
      "first_name" => "",
      "last_name" => "",
      "affiliation" => "",
      "password-retype" => ""
    }
  end

  def show
    # When user is loged in they can see who they are and what their profile is
    initRackEnv( env )
    controller = self
    GbDb::GbUser.byLogin( env, @currRmUser.login ) { |result|
      @gu = result[:obj]
      if ! @gu.userId.nil?
        @gu.renderToClient( controller, :show_current_user )
      else 
        renderToClient( controller, :gb_user_err )
      end
    }
    throw :async
  end

  def edit
    initRackEnv( env )
    controller = self
    GbDb::GbUser.byLogin( env, @currRmUser.login ) { |result|
      @gu = result[:obj]
      @user_info = Hash.new
      if ! @gu.userId.nil?
        @user_info = { 
          "user_id"  => @gu.login,
          "e-mail"  => @gu.email,
          "first_name"  => @gu.firstName,
          "last_name"  => @gu.lastName,
          "affiliation"  => @gu.institution
        }
        renderToClient( controller, :edit )
      else 
        renderToClient( controller, :gb_user_err )
      end
    }
    throw :async
  end

  def editpwd
  end

  # When user wants to update password
  def updatep
    @pwd_info = params
    initRackEnv( env )
    controller = self

    GbDb::GbUser.byLogin( env, @currRmUser.login ) { |result|
      begin
        @gu = result[:obj]
        if @pwd_info["password"] == @pwd_info["password-retype"]
          if ! @gu.userId.nil?
            if @gu.password == @pwd_info["current_password"]
              @gu.passwordUpdate(@gu.login, @pwd_info["password"]) { |result|
                flash[:success] = "Password updated"
                @gu.renderToClient( controller, :show_current_user )
              }
            else
              flash[:error] = "Old password doesnot match with the record"
              renderToClient( controller, :editpwd )
            end
          else
            flash[:error] = "The login does not exist"
            renderToClient( controller, :editpwd )
          end
        else
          flash[:error] = "Passwords don't match"
          renderToClient( controller, :editpwd )
        end
      rescue => err
        flash[:error] = "Error: #{err.class} => #{err.message}"
        renderToClient( controller, :editpwd )
      end
    }
    throw :async
  end

  # When user wants to update information other than password: 
  # e.g. email, firstname, lastname, affiliation
  def updatel
    @user_info = params
    initRackEnv( env )
    controller = self
    # Search user by login
    GbDb::GbUser.byLogin( env, @currRmUser.login ) { |result|
      begin
        @gu = result[:obj]
        # Change first name last name and affiliation
        @gu.upsert(@gu.login, @gu.email,@gu.password,
                   @user_info["affiliation"], @user_info["first_name"], 
                   @user_info["last_name"],
                   @gu.phone, { :syncToRedmine => true } ){ |result|
          if @gu.email == @user_info["e-mail"]
            flash[:success] = "Record updated"
            @gu.renderToClient( controller, :show_current_user );
          else 
            GbDb::GbUser.byEmail( env, @user_info["e-mail"]){ |result| 
              @gu2 = result[:obj]
              if ! @gu2.userId.nil?
                flash[:error] = "E-mail id is associate with other record"
                renderToClient( controller, :edit );
              else
                # Update the record
                @gu.emailUpdate(@gu.login, @user_info["e-mail"]) { |result|
                  $stderr.puts "CGUSER - print after email update #{result}"
                  flash[:success] = "Record updated"
                  @gu.renderToClient( controller, :show_current_user )
                }
              end
            }
          end
        }
      rescue => err
        flash[:error] = "Error: #{err.class} => #{err.message}"
        renderToClient( controller, :edit )
      end
    }
    throw :async
  end

  def create

    @user_info = params
    initRackEnv( env )
    controller = self

    if @user_info["password"] == @user_info["password-retype"]
      GbDb::GbUser.byLogin( env , @user_info["user_id"] ) { |result|
        begin # begin the error handling
          if result.keys.include?(:obj)
               @gu = result[:obj] 
               if ! @gu.userId.nil?
                 flash[:error] = "The user id is taken"
                 renderToClient( controller, :new )
               else
                 # Is email taken already?
                 GbDb::GbUser.byEmail( env, @user_info["e-mail"] ) { |result|
                   @gu = result[:obj] or result[:err]
                   if result.keys.include?(:obj)
                     if ! @gu.userId.nil?
                       flash[:error] = "The email-id is taken"
                       renderToClient( controller, :new )
                     else
                       # Is userid/login taken already?
                       GbDb::GbUser.create( rackEnv, @user_info["user_id"], @user_info["e-mail"], @user_info["password"], @user_info["affiliation"], @user_info["first_name"], @user_info["last_name"], ""){ |result| 
                         if result.keys.include?(:obj) # create success
                           $stderr.debugPuts(__FILE__, __method__, 'DEBUG', "++++++ CREATE CLINGEN USER: Genboree user is created now #{result.inspect}")
                           gu_for_redmine = result[:obj]
                           if( gu_for_redmine.is_a?( GbDb::GbUser ) ) # the gu_for_redmine is fine
                              # Create redmine shaddow record
                              gu_for_redmine.createRedmineEntity { |red_result|
                                 $stderr.debugPuts(__FILE__, __method__, 'DEBUG', "++++++ CREATE CLINGEN USER: In call back of createRedmine Entity #{red_result.inspect}")
                                 gu_from_redmine = red_result[:obj] or nil
                                 if(gu_from_redmine)
                                   $stderr.debugPuts(__FILE__, __method__, 'DEBUG', "++++++ CREATE CLINGEN USER: The response is good will render good_to_go. #{gu_from_redmine}")
                                   giveAccessToRegistry(env, @user_info["user_id"]){|reg_access_results|
                                     if(reg_access_results[:obj])
                                       $stderr.debugPuts(__FILE__, __method__, 'DEBUG', "++++++ CREATE CLINGEN USER: Inside call back of giveAccessToRegistry. This is the argument from bodyFinish #{reg_access_results.inspect}")
                                       flash[:success] = "Succesfully created login and provided access to ClinGen Resources."
                                       renderToClient( controller, :good_to_go )
                                     else 
                                       $stderr.debugPuts(__FILE__, __method__, 'DEBUG', "++++++ CREATE CLINGEN USER: Inside call back of giveAccessToRegistry. This is the argument from bodyFinish #{reg_access_results.inspect}")
                                       flash[:error] = "#{reg_access_results.inspect}"
                                       renderToClient( controller, :new )
                                     end
                                   } # end of giveAccessToRegistry call
                                 else
                                   $stderr.debugPuts(__FILE__, __method__, 'DEBUG', "++++++ CREATE CLINGEN USER: Failed to create redmine shaddow. #{red_result.inspect}")
                                   flash[:error] = "Failed to create redmine shaddow. #{red_result.inspect}"
                                   renderToClient( controller, :new )
                                 end
                              } # end async of createRedmineEntity
                           else # the gu_for_redmine is problematic or exist already
                             $stderr.debugPuts(__FILE__, __method__, 'DEBUG', "++++++ CREATE CLINGEN USER: gu_for_redmine is not of type GbDb:GbUser #{gu_for_redmine.inspect}")
                             flash[:error] = "Object returned in result[:obj] is not of class GbDb::GbUser. #{gu_for_redmine.inspect}"
                             renderToClient( controller, :new )
                           end
                         else # Create ended up in error
                           $stderr.debugPuts(__FILE__, __method__, 'DEBUG', "++++++ CREATE CLINGEN USER: User WAS NOT created successfully. Recieved an error #{result.inspect}")
                           flash[:error] = result[:err] or "Unknown error occured"
                           renderToClient( controller, :new )
                         end
                       } # Create call back ends here
                     end # email id checks over
                   else
                     # What to do if email check failed
                     $stderr.debugPuts(__FILE__, __method__, 'DEBUG', "++++++ CREATE CLINGEN USER: Recieved and error while getting back from check email call #{result.inspect}")
                     flash[:error] = result[:err] or "Unknown error occured"
                     renderToClient( controller, :new )
                   end # After email check ends here
                 } # Call back for email check
               end  # User id check ends
          else 
            $stderr.debugPuts(__FILE__, __method__, 'DEBUG', "++++++ CREATE CLINGEN USER: The first check to see if the login is already taken resulted in error #{result.inspect}")
            flash[:error] = result[:err] or "Unknown error occured"
            renderToClient( controller, :new )
          end
        rescue => err
          $stderr.puts "CGUSER - User WAS NOT created successfully."
          flash[:error] = "CGUSER - User WAS NOT created successfully."
          renderToClient( controller, :new )
        end
      } # Search login by user id ends
    else 
      $stderr.puts "CGUSER - Passwords don't match"
      flash[:error] = "Password don't match"
      renderToClient( controller, :new )
    end

    throw :async
  end

  def resetp
    @user_info = {
      "user_id" => "", 
      "e-mail" => ""
    }
  end

  # This is the controller that handles sending password reset request
  def send_reset_request
    @user_info = params
    $stderr.debugPuts(__FILE__, __method__, 'DEBUG', "++++++ CREATE CLINGEN USER: Send password reset request #{params.inspect}")
    initRackEnv( env )
    controller = self
    GbDb::GbUser.byLogin( env, params["user_id"]){ |result|
      $stderr.debugPuts(__FILE__, __method__, 'DEBUG', "++++++ CREATE CLINGEN USER: Inside call back #{result.inspect}")
      begin
         @gu = result[:obj] or result[:err]
         if(result[:obj])
             if @gu.email == params["e-mail"]
               # If email matches 
               $stderr.debugPuts(__FILE__, __method__, 'DEBUG', "++++++ CREATE CLINGEN USER: Reseting password #{result.inspect}")
               # Generate password
               o = [('a'..'z'), ('A'..'Z'), (0..9)].map(&:to_a).flatten
               newp = (0...8).map{o[rand(o.length)]}.join
               # Go reset password
               @gu.passwordUpdate(@gu.login, newp) { |result|
                 $stderr.debugPuts(__FILE__, __method__, 'DEBUG', "++++++ CREATE CLINGEN USER: Inside the call back of password Update")
                 if(result[:obj] or result[:count])
                  # Send mail
                  $stderr.debugPuts(__FILE__, __method__, 'DEBUG', "++++++ CREATE CLINGEN USER: Password updated which is #{newp}")
                  MailNotificationsMailer.password_reset_notice( User.find_by_login(@gu.login), newp ).deliver
                  $stderr.debugPuts(__FILE__, __method__, 'DEBUG', "++++++ CREATE CLINGEN USER: Sent email")
                  flash[:success] = "Password reset information sent to your email address: #{@gu.email}"
                  $stderr.debugPuts(__FILE__, __method__, 'DEBUG', "++++++ CREATE CLINGEN USER: Redirect to client")
                  @gu.renderToClient( controller, :resetp )
                 else
                  $stderr.debugPuts(__FILE__, __method__, 'DEBUG', "++++++ CREATE CLINGEN USER: Can't update password #{result.inspect}")
                  flash[:error] = "Failed to update password. "
                  @gu.renderToClient( controller, :resetp )
                 end
               }
             else
               # If email doesn't match
               $stderr.debugPuts(__FILE__, __method__, 'DEBUG', "++++++ CREATE CLINGEN USER: Login/email-mismatch: Supplied record: #{params.inspect} and Retrieved record: #{@gu.inspect}")
               flash[:error] = "The provided email-id #{params["e-mail"]} doesnot match with the record we have for #{params["user_id"]}."
               @gu.renderToClient( controller, :resetp )
             end
         else
           $stderr.debugPuts(__FILE__, __method__, 'DEBUG', "++++++ CREATE CLINGEN USER: Login #{params["user_id"]} does not exist")
           flash[:error] = "Error while retrieving information for #{params["user_id"]}."
           @gu.renderToClient( controller, :resetp )
         end
      rescue
         $stderr.debugPuts(__FILE__, __method__, 'DEBUG', "++++++ CREATE CLINGEN USER: Something went wrong while reseting password. #{result.inspect}")
         flash[:error] = "Something went wrong while retrieving record for #{params["user_id"]}."
         @gu.renderToClient( controller, :resetp )
      end
    }
    throw :async
  end

  private 

  def find_project
    @project = Project.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end
  def set_host
    @gbHost =  @project_settings.gb_host
      #"10.15.55.128"
  end

  def set_honor
    # Piotr: this needs a change based on deployment
    # This is the user who is admin to Registry/Calculator related resources
    @great_honor = User.find_by_login(@project_settings.privilaged_user)
  end

  def set_project_settings
       @project_settings = ClingenResourceSetting.find_by_project_id(@project.id)
  end

  def set_controller_action
    @curr_action = "#{controller_name}/#{action_name}"
    $stderr.debugPuts(__FILE__, __method__, 'DEBUG', "++++++ CREATE CLINGEN USER: current_action is #{@curr_action}.")
  end

  def project_specific_authorize
    $stderr.debugPuts(__FILE__, __method__, 'DEBUG', "++++++ CREATE CLINGEN USER: controler-action => #{@curr_action}")
    $stderr.debugPuts(__FILE__, __method__, 'DEBUG', "++++++ CREATE CLINGEN USER: current user => #{@currRmUser.inspect}")
    allowed = Redmine::AccessControl.permissions.select{ |xx| 
      xx.actions.include? (@curr_action)
    }.any?{|perm| 
      @currRmUser.roles_for_project(@project).any?{|role| 
        role.permissions.include?(perm.name)
      }
    } rescue false
    $stderr.debugPuts(__FILE__, __method__, 'DEBUG', "++++++ CREATE CLINGEN USER: User #{@currRmUser.inspect} allowed for #{@curr_action} => #{allowed}")

   if ! allowed
    $stderr.debugPuts(__FILE__, __method__, 'DEBUG', "++++++ CREATE CLINGEN USER: Before rendering 403")
    authorize
    #render_403 :message => :permission_denied
   end
   $stderr.debugPuts(__FILE__, __method__, 'DEBUG', "++++++ CREATE CLINGEN USER: At the end of method.")
  end

end
