class GenboreeProfileManagementUiUpdateController < ApplicationController  

  include GenboreeProfileManagementHelper
  include GbMixin::AsyncRenderHelper
  unloadable

  before_filter :find_project, :redirect_anon_to_login, :init_user_info, :getKbMount
  layout 'gb_profile_man_main'
  
  def show
    initRackEnv( env )
    controller = self
    GbDb::GbUser.byLogin( env, @currRmUser.login ) { |result|
      begin
        @gu = result[:obj]
        @user_info = Hash.new
        if(!@gu.userId.nil?)
          @user_info = { 
            "user_id"  => @gu.login,
            "email_id"  => @gu.email,
            "first_name"  => @gu.firstName,
            "last_name"  => @gu.lastName,
            "affiliation"  => @gu.institution,
            "phone"  => @gu.phone
          }
          # In certain cases, because unique emails were not being enforced for every user, it is possible that the email id for this user matches the email of another user. If that is the case, we will not allow this user to update his profile and will instead ask the user to contact us to resolve this issue
          GbDb::GbUser.byEmail( env, @gu.email ) { |result|
            begin
              if(result.key?(:obj))
                byEmailGu = result[:obj]
                if(byEmailGu.login == @gu.login)
                  renderToClient( controller, :show )
                else
                  flash[:error] = "The email id in your account is linked to multiple profiles including yours. Use of the same email for different Genboree profiles is no longer supported. Please update the email id and save your changes."
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
  
  
  
  def update()
    @user_info = params
    initRackEnv( env )
    controller = self
    GbDb::GbUser.byLogin( env, @currRmUser.login ) { |result|
      begin
        @gu = result[:obj]
        @gu.upsert(@gu.login, @user_info["email_id"], @gu.password,
                   @user_info["affiliation"], @user_info["first_name"], 
                   @user_info["last_name"],
                   @gu.phone, { :syncToRedmine => true } ){ |result|
          begin
            $stderr.puts "update_result:\n#{result.inspect}"
            if(result.key?(:count))
              flash[:success] = "Profile Updated."
              @user_info["user_id"] = @gu.login
              renderToClient( controller, :updated );
            else
              flash[:error] = result[:err] or "Unknown error occured"
              renderToClient( controller, :show )
            end
          rescue => err
            flash[:error] = "Error: #{err.class} => #{err.message}"
            renderToClient( controller, :show )
          end
        }
      rescue => err
        $stderr.debugPuts(__FILE__, __method__, 'ERROR', "ERROR: #{err}\n\nTRACE: #{err.backtrace.join("\n")}")
        flash[:error] = "Error: #{err.class} => #{err.message}"
        renderToClient( controller, :show )
      end
    }
    throw :async
  end
  
  def show_update_pwd
    render :show_update_pwd
  end
  
  def update_pwd
    @pwd_info = params
    initRackEnv( env )
    controller = self
    GbDb::GbUser.byLogin( env, @currRmUser.login ) { |result|
      begin
        @gu = result[:obj]
        if(@gu.password == @pwd_info["current_password"])
          @gu.passwordUpdate(@gu.login, @pwd_info["password"]) { |result|
            flash[:success] = "Password Updated."
            @user_info = { 
              "user_id"  => @gu.login,
              "email_id"  => @gu.email,
              "first_name"  => @gu.firstName,
              "last_name"  => @gu.lastName,
              "affiliation"  => @gu.institution,
              "phone"  => @gu.phone
            }
            @gu.renderToClient( controller, :updated )
          }
        else
          flash[:error] = "Your 'Current password' is incorrect."
          renderToClient( controller, :show_update_pwd )
        end
      rescue => err
        $stderr.debugPuts(__FILE__, __method__, 'ERROR', "ERROR: #{err}\n\nTRACE: #{err.backtrace.join("\n")}")
        flash[:error] = "Error: #{err.class} => #{err.message}"
        renderToClient( controller, :show_update_pwd )
      end
    }
    throw :async
  end

end