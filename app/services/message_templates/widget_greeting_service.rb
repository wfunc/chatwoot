class MessageTemplates::WidgetGreetingService
  def initialize(contact_inbox:, session_id: nil, conversation: nil, message: nil)
    @contact_inbox = contact_inbox
    @session_id = session_id
    @conversation = conversation
    @message = message
  end

  def perform
    return unless enabled?

    # Use a fresh record: the incoming-message callback can hold dirty associated records.
    Contact.find(@contact_inbox.contact_id).with_lock do
      next if history_exists?

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
    inbox.greeting_enabled? && inbox.greeting_message.present? && (@message.present? || @session_id.present?)
  end

  def history_exists?
    conversations = inbox.conversations.where(contact_id: @contact_inbox.contact_id)
    history = inbox.messages.chat.where(conversation_id: conversations.select(:id))
    return history.exists? unless @message
    return true if history.exists?(['messages.id < ?', @message.id])

    # Ignore replies created by this first message (such as an out-of-office reply),
    # but detect an already delivered greeting when its callback is retried.
    # Read through the model serializer: content_attributes can be JSON-encoded strings.
    history.template.where('messages.id > ?', @message.id).reorder(nil)
           .select(:id, :content_attributes).find_each.any? { |message| message.content_attributes['channel_greeting'] }
  end

  def captain_handling_conversation?
    @conversation.pending? && inbox.respond_to?(:captain_assistant) && inbox.captain_assistant.present?
  end
end
