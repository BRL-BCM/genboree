class MailNotificationsMailer < Mailer
  def password_reset_notice( user, newp, timestamp=Time.now )
        @user = user
        @newp = newp
        @time = timestamp - (7*24*60*60)
        mail( :to => user.mail, :subject => "Password reset request for BCM-ClinGen resources" )
  end
end
