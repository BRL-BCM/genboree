class GenboreeProfileManagementUiEntryController < ApplicationController  

  include GenboreeProfileManagementHelper
  include GbMixin::AsyncRenderHelper
  unloadable

  before_filter :find_project, :init_user_info, :getKbMount
  before_filter :redirect_anon_to_login, :only => [:profile]
  layout 'gb_profile_man_main'

  # Main view action
  # If user is logged in, show the user's profile.
  # Otherwise, show a 'new resgistration' page.
  def show()
    if(@currRmUser.type != "AnonymousUser")
      redirect_to :action => "profile"
    else
      render :new
    end
  end
  
  
  def profile
    initRackEnv( env )
    controller = self
    GbDb::GbUser.byLogin( env, @currRmUser.login ) { |result|
      begin
        if(result.key?(:obj))
          @gu = result[:obj]
          @user_info = Hash.new
          if(!@gu.userId.nil?)
            @user_info = { 
              "user_id"  => @gu.login,
              "email_id"  => @gu.email,
              "first_name"  => @gu.firstName,
              "last_name"  => @gu.lastName,
              "affiliation"  => @gu.institution,
              "phone" => @gu.phone
            }
            renderToClient( controller, :show )
          else
            flash[:error] = result[:err] or "Unknown error occured"
            renderToClient( controller, :show )
          end
        else
          flash[:error] = result[:err] or "Unknown error occured"
          renderToClient( controller, :show )
        end
      rescue => err
        $stderr.debugPuts(__FILE__, __method__, 'ERROR', "ERROR: #{err}\n\nTRACE: #{err.backtrace.join("\n")}")
        flash[:error] = "Error: #{err.class} => #{err.message}"
        renderToClient( controller, :show )
      end
    }
    throw :async
  end
  
  
  # Used for checking (live lookup) if the login entered by a user already exists
  # If login already exists, send back a 4XX error which will be appropriately handled by the bootstrap validator plugin
  def validate_user_id()
    user_id = params['user_id']
    initRackEnv( env )
    controller = self
    GbDb::GbUser.byLogin( env , user_id ) { |result|
      begin # begin the error handling
        @gu = result[:obj] 
        if(!@gu.userId.nil?)
          sendToClient(409, {'Content-Type' => 'text/html'}, "This login has been taken" )
        else
          sendToClient( 200, {'Content-Type' => 'text/html'}, "" )
        end
      rescue => err
        $stderr.puts "Validating user_id failed with error: #{err}\n\nTRACE:\n#{err.backtrace.join("\n")}"
        sendToClient( 500, {'Content-Type' => 'text/html'}, err )
      end
    }
    throw :async
  end
  
  # Used for checking (live lookup) if the email entered by a user already exists
  # If email already exists (for a different user), send back a 4XX error which will be appropriately handled by the bootstrap validator plugin
  def validate_email_id()
    email_id = params['email_id']
    initRackEnv( env )
    controller = self
    GbDb::GbUser.byEmail( env, email_id ) { |result|
      begin # begin the error handling
        #$stderr.puts "byEmail result:\n#{result.inspect}"
        @gu = result[:obj]
        # If user is updating self profile, we need to not include his/her own email id
        # There is also a case where a user is logged in but is creating anew user. In that case, context will be new.
        if(params['context'] != "new")
          if(@gu.userId.nil?)
            sendToClient( 200, {'Content-Type' => 'text/html'}, "" )
          else
            # Get the details of the user and compare the current email with the entered email. It's OK if they match.
            GbDb::GbUser.byLogin( env, @currRmUser.login ) { |result|
              logged_in_gu = result[:obj]
              if(!logged_in_gu.nil?)
                if(logged_in_gu.login == @gu.login)
                  sendToClient( 200, {'Content-Type' => 'text/html'}, "" )
                else
                  sendToClient(409, {'Content-Type' => 'text/html'}, "This email has been taken." )
                end
              else
                err = result[:err] or "Unknown error occured"
                sendToClient( 500, {'Content-Type' => 'text/html'}, err )
              end
            }
          end
        else
          if(!@gu.userId.nil?)
            sendToClient(409, {'Content-Type' => 'text/html'}, "This email has been taken." )
          else
            sendToClient( 200, {'Content-Type' => 'text/html'}, "" )
          end
        end
      rescue => err
        $stderr.puts "Validating email_id failed with error: #{err}\n\nTRACE:\n#{err.backtrace.join("\n")}"
        sendToClient( 500, {'Content-Type' => 'text/html'}, err )
        
      end
    }
    throw :async
  end
  
  # Create a new user
  # Add a new user record in Genboree
  def create()
    @user_info = params
    initRackEnv( env )
    controller = self
    @user_info = params
    GbDb::GbUser.create( rackEnv, @user_info["user_id"], @user_info["email_id"], @user_info["password"], @user_info["affiliation"], @user_info["first_name"], @user_info["last_name"], @user_info["phone"]){ |result|
      begin
        if(result.keys.include?(:obj))
          gu_for_redmine = result[:obj]
          gu_for_redmine.createRedmineEntity { |red_result|
            gu_from_redmine = red_result[:obj] or nil
            if(gu_from_redmine)
              flash[:success] = "User Registration Successful."
              renderToClient( controller, :registration_successful )
            else
              flash[:error] = result[:err] or "Unknown error occured"
              renderToClient( controller, :new )
            end
          }
        else # Create ended up in error
          $stderr.debugPuts(__FILE__, __method__, 'DEBUG', "++++++ CREATE GENBOREE USER: User WAS NOT created successfully. Recieved an error #{result.inspect}")
          flash[:error] = result[:err] or "Unknown error occured"
          renderToClient( controller, :new )
        end
      rescue => err
        $stderr.debugPuts(__FILE__, __method__, 'ERROR', "ERROR: #{err}\n\nTRACE: #{err.backtrace.join("\n")}")
        flash[:error] = "Error: #{err.class} => #{err.message}"
        renderToClient( controller, :new )
      end
    } # Create call back ends here
    
    throw :async
  end
  
  def forgot_pwd
    render :forgot_pwd
  end
  
  # Overloaded function/action. Handles reseting password and sending login info to user specified email
  def reset_pwd
    @user_info = params
    initRackEnv( env )
    controller = self
    GbDb::GbUser.byEmail( env, @user_info["email_id"]){ |result|
      begin
        if(result.key?(:obj) and result[:obj].login)
          @gu = result[:obj]
          #$stderr.debugPuts(__FILE__, __method__, 'DEBUG', "result:\n#{result.inspect}")
          # User has requested for login id to be sent
          if(@user_info.key?("send_login_info"))
            $stderr.debugPuts(__FILE__, __method__, 'STATUS', "++++++Genboree User: Sending login info")
            GbProfileManagementMailer.send_login( @gu ).deliver
            $stderr.debugPuts(__FILE__, __method__, 'DEBUG', "++++++ Genboree USER: Sent email")
            flash[:success] = "Login information sent to your email address: #{@gu.email}"
            @gu.renderToClient( controller, :forgot_pwd )
          else # User has requested for password to be reset
            $stderr.debugPuts(__FILE__, __method__, 'STATUS', "++++++Genboree User: Reseting password..")
            # Generate password
            o = [('a'..'z'), ('A'..'Z'), (0..9)].map(&:to_a).flatten
            newp = (0...8).map{o[rand(o.length)]}.join
            # Go reset password
            @gu.passwordUpdate(@gu.login, newp) { |result|
              if(result[:obj] or result[:count])
                # Send mail
                GbProfileManagementMailer.reset_password( @gu, newp ).deliver
                $stderr.debugPuts(__FILE__, __method__, 'DEBUG', "++++++ Genboree USER: Sent email")
                flash[:success] = "Password reset information sent to your email address: #{@gu.email}"
                @gu.renderToClient( controller, :forgot_pwd )
              else
                $stderr.debugPuts(__FILE__, __method__, 'ERROR', "++++++ Genboree USER: Can't reset password #{result.inspect}")
                error = result[:err] || "Unknown error"
                flash[:error] = "Failed to reset password: #{error}"
                @gu.renderToClient( controller, :forgot_pwd )
              end
            }
          end
        else
          flash[:error] = "We could not find any Genboree profile with the email: #{@user_info["email_id"]}."
          renderToClient( controller, :forgot_pwd )
        end
      rescue => err
        $stderr.debugPuts(__FILE__, __method__, 'ERROR', "ERROR: #{err}\n\nTRACE:\n#{err.backtrace.join("\n")}")
        flash[:error] = "Error: #{err.class} => #{err.message}"
        renderToClient( controller, :forgot_pwd )
      end
    }
    throw :async
  end

end