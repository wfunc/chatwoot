module EnsureCurrentAccountHelper
  private

  def current_account
    @current_account ||= ensure_current_account
    Current.account = @current_account
  end

  def ensure_current_account
    account = Account.find(params[:account_id])
    render_unauthorized('Account is suspended') and return unless account.active?

    if current_user
      account_accessible_for_user?(account)
    elsif @resource.is_a?(AgentBot)
      account_accessible_for_bot?(account)
    end
    account
  end

  def account_accessible_for_user?(account)
    @current_account_user = account.account_users.find_by(user_id: current_user.id)
    Current.account_user = @current_account_user
    render_unauthorized('You are not authorized to access this account') unless @current_account_user
    return if @current_account_user.blank?

    sync_expired_merchant_status(@current_account_user)
    return if @current_account_user.active_for_dashboard?

    render_unauthorized(merchant_access_error_message(@current_account_user))
  end

  def account_accessible_for_bot?(account)
    return if @resource.account_id == account.id
    return if @resource.agent_bot_inboxes.find_by(account_id: account.id)

    render_unauthorized('Bot is not authorized to access this account')
  end

  def sync_expired_merchant_status(account_user)
    owner = account_user.merchant_owner
    return if owner.blank?
    return unless owner.merchant_expires_at.present? && owner.merchant_expires_at <= Time.current
    return if owner.expired?

    owner.update_column(:merchant_status, AccountUser.merchant_statuses[:expired])
  end

  def merchant_access_error_message(account_user)
    return 'Merchant account is suspended' if account_user.merchant_state == 'suspended'
    return 'Merchant account has expired' if account_user.merchant_state == 'expired'

    'You are not authorized to access this account'
  end
end
