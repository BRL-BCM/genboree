class GbProfileManagementMailer < Mailer
  
  def reset_password( user, newp, timestamp=Time.now )
    @user = user
    @time = timestamp - (7*24*60*60)
    @newp = newp
    subjPrefix = "Genboree - Profile Management"
    mail( :to => user.email, :subject => "#{subjPrefix} -- Reset Password" )
  end
  
  def send_login(user)
    subjPrefix = "Genboree - Profile Management"
    @user = user
    mail( :to => user.email, :subject => "#{subjPrefix} -- Login Info" )
  end
  
end