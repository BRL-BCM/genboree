class GbIllustrativeMailer < Mailer
  def custom_mail_notice( user, someArg, timestamp=Time.now )
    # @variables here will be available as @variables in the EMAIL VIEW TEMPLATE (email is MVC)
    # - So make @variables based on incoming arg info and such. Pass in
    @user = user
    @time = timestamp - (7*24*60*60)
    @someArg = someArg
    # Subject hould have SOME PREFIX obtained from a plugin setting or whatever which user can used to FILTER THEIR EMAIL EASILY.
    # * Here we use something for this "application/plugin" (genboree_generic)
    # * Note that the global redmine email prefix set in the Adminstration UI area is AUTOMATICALLY applied to all emails.
    subjPrefix = "Generic e.g."
    # send the mail...it will look for the custom_email1 VIEW for this mailer model of course and use that to format body
    # * You should have BOTH .html.erb and .text.erb views! Send html email with plain text fallback!
    # * i.e. look at plugins/genboree_generic/app/views/gb_illustrative_mailer/custom_mail_notice.*
    mail( :to => user.mail, :subject => "#{subjPrefix} -- ARJ Mail Test for Mr. #{user.lastname}" )
  end
end