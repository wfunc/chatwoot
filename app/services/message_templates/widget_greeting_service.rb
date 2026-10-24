class MessageTemplates::WidgetGreetingService
  def initialize(contact_inbox:, session_id:, conversation: nil)
    @contact_inbox = contact_inbox
    @session_id = session_id
    @conversation = conversation
  end

  def perform
    return unless enabled?

    @contact_inbox.with_lock do
      next if already_greeted?

      @conversation ||= yield
      next if @conversation.campaign.present? || captain_handling_conversation?

      @conversation.messages.create!(
        account_id: inbox.account_id,
        inbox_id: inbox.id,
        message_type: :template,
        content: inbox.greeting_message,
        content_attributes: { channel_greeting: true, greeting_session_id: @session_id }
      )
    end
  end

  private

  delegate :inbox, to: :@contact_inbox

  def enabled?
    inbox.greeting_enabled? && inbox.greeting_message.present? && @session_id.present?
  end

  def already_greeted?
    greetings = inbox.messages.where(conversation_id: @contact_inbox.conversations.select(:id))
                     .where("content_attributes ->> 'channel_greeting' = ?", 'true')
    return greetings.exists? if inbox.greeting_first_open?

    greetings.exists?(["content_attributes ->> 'greeting_session_id' = ?", @session_id])
  end

  def captain_handling_conversation?
    @conversation.pending? && inbox.respond_to?(:captain_assistant) && inbox.captain_assistant.present?
  end
end
