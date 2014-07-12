module Subscribable
  extend ActiveSupport::Concern

  def subscription_for(user)
    subscriptions.where(user_id: user).first_or_initialize do |s|
      s.subscribed = false
      s.reason = "You are not receiving emails because you are not subscribed."
    end
  end

  def subscribers
    subscriptions.includes(:user).map(&:user)
  end
end
