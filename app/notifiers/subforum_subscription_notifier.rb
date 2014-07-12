require 'set'

class SubforumSubscriptionNotifier < Notifier
  attr_reader :thread

  def initialize(thread)
    @thread = thread
  end

  def notify(email_recipients)
    unless email_recipients.empty?
      mail = NotificationMailer.new_thread_in_subscribed_subforum_email(email_recipients, thread)
      BatchMailSender.new(mail).delay.deliver
    end
  end

  def possible_recipients
    @possible_recipients ||= thread.subforum.subscribers.select { |u| Ability.new(u).can? :read, thread}.to_set
  end
end
