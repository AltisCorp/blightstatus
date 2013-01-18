class AccountMailer < ActionMailer::Base
  default from: "blightstatus@nola.gov"

  def deliver_digest(user, subs)
    @user = user
    @subs = subs
    mail(:to => @user.email, :subject => "Blightstatus notifications for #{Time.now.to_date}")
  end
end
