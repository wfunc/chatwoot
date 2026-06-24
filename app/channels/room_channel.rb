class RoomChannel < ApplicationCable::Channel
  def subscribed
    # TODO: should we only do ensure stream  if current account is present?
    # for now going ahead with guard clauses in update_subscription and broadcast_presence
    current_user
    current_account
    ensure_stream
    update_subscription
    broadcast_presence
  end

  def update_presence
    update_subscription
    broadcast_presence
  end

  def unsubscribed
    return if @current_account.blank? || @current_user.blank?

    remove_subscription
    broadcast_account_presence
  end

  private

  def broadcast_presence
    return if @current_account.blank?

    ActionCable.server.broadcast(pubsub_token, { event: 'presence.update', data: presence_payload })
  end

  def broadcast_account_presence
    ActionCable.server.broadcast("account_#{@current_account.id}", { event: 'presence.update', data: presence_payload })
  end

  def ensure_stream
    stream_from pubsub_token
    stream_from "account_#{@current_account.id}" if @current_account.present? && @current_user.is_a?(User)
    stream_from auth_client_stream if auth_client_stream.present?
  end

  def update_subscription
    return if @current_account.blank?

    ::OnlineStatusTracker.update_presence(@current_account.id, @current_user.class.name, @current_user.id)
  end

  def remove_subscription
    ::OnlineStatusTracker.remove_presence(@current_account.id, @current_user.class.name, @current_user.id)
  end

  def presence_payload
    data = { account_id: @current_account.id, users: ::OnlineStatusTracker.get_available_users(@current_account.id) }
    data[:contacts] = ::OnlineStatusTracker.get_available_contacts(@current_account.id)
    data
  end

  def pubsub_token
    @pubsub_token ||= params[:pubsub_token]
  end

  def auth_client
    @auth_client ||= params[:auth_client].presence
  end

  def auth_client_stream
    return if auth_client.blank? || !@current_user.is_a?(User) || @current_user.tokens.blank?
    return if @current_user.tokens[auth_client].blank?

    Auth::ClientRevocationNotifier.stream_name(@current_user.id, auth_client)
  end

  def current_user
    @current_user ||= if params[:user_id].blank?
                        ContactInbox.find_by!(pubsub_token: pubsub_token).contact
                      else
                        User.find_by!(pubsub_token: pubsub_token, id: params[:user_id])
                      end
  end

  def current_account
    return if current_user.blank?

    @current_account ||= if @current_user.is_a? Contact
                           @current_user.account
                         else
                           @current_user.accounts.find(params[:account_id])
                         end
  end
end
