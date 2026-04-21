module WidgetHelper
  def build_contact_inbox_with_token(web_widget, additional_attributes = {})
    contact_inbox = web_widget.create_contact_inbox(additional_attributes)
    token = build_widget_auth_token(web_widget, contact_inbox)

    [contact_inbox, token]
  end

  def build_contact_inbox_token_for_source(web_widget, contact, source_id, hmac_verified: false)
    contact_inbox = ::ContactInboxBuilder.new(
      contact: contact,
      inbox: web_widget.inbox,
      source_id: source_id,
      hmac_verified: hmac_verified
    ).perform

    [contact_inbox, build_widget_auth_token(web_widget, contact_inbox)]
  end

  def build_widget_auth_token(web_widget, contact_inbox)
    payload = { source_id: contact_inbox.source_id, inbox_id: web_widget.inbox.id }
    ::Widget::TokenService.new(payload: payload).generate_token
  end
end
