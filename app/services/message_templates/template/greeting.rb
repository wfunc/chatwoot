class MessageTemplates::Template::Greeting
  pattr_initialize [:conversation!]

  def perform
    conversation.with_lock do
      next if greeting_already_sent?

      conversation.messages.create!(greeting_message_params)
    end
  rescue StandardError => e
    ChatwootExceptionTracker.new(e, account: conversation.account).capture_exception
    true
  end

  private

  delegate :contact, :account, to: :conversation
  delegate :inbox, to: :message

  def greeting_already_sent?
    return false unless conversation.inbox.web_widget? && conversation.inbox.greeting_first_message?

    conversation.messages.template.exists?(["content_attributes ->> 'channel_greeting' = ?", 'true'])
  end

  def greeting_message_params
    content = @conversation.inbox&.greeting_message

    {
      account_id: @conversation.account_id,
      inbox_id: @conversation.inbox_id,
      message_type: :template,
      content: content,
      content_attributes: { channel_greeting: true }
    }
  end
end
