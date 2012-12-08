class Subscription < ActiveRecord::Base
  belongs_to :account
  belongs_to :address

  def updated_since_last_notification?
    last_notified = date_notified || Date.new(1970, 2, 3)
    if address && address.workflow_steps
      address.workflow_steps.any?{ |step| step.updated_at > last_notified && step.date > last_notified}
    end
  end
end
