class Api::V1::Accounts::AgentsController < Api::V1::Accounts::BaseController
  before_action :fetch_agent, except: [:create, :index, :bulk_create]
  before_action :check_authorization
  before_action :validate_limit, only: [:create]
  before_action :validate_limit_for_bulk_create, only: [:bulk_create]

  def index
    @agents = agents
  end

  def create
    builder = AgentBuilder.new(
      email: new_agent_params['email'],
      name: new_agent_params['name'],
      password: new_agent_params['password'],
      password_confirmation: new_agent_params['password_confirmation'],
      role: resolved_role,
      availability: new_agent_params['availability'],
      auto_offline: new_agent_params['auto_offline'],
      merchant_status: new_agent_params['merchant_status'],
      merchant_expires_at: new_agent_params['merchant_expires_at'],
      agent_limit: new_agent_params['agent_limit'],
      parent_merchant_id: resolved_parent_merchant_id,
      inviter: current_user,
      account: Current.account
    )

    @agent = builder.perform
  end

  def update
    @agent.update!(filtered_user_params)
    @agent.current_account_user.update!(filtered_account_user_params)
  end

  def destroy
    @agent.current_account_user.destroy!
    delete_user_record(@agent)
    head :ok
  end

  def bulk_create
    emails = params[:emails]

    emails.each do |email|
      builder = AgentBuilder.new(
        email: email,
        name: email.split('@').first,
        inviter: current_user,
        account: Current.account
      )
      begin
        builder.perform
      rescue ActiveRecord::RecordInvalid => e
        Rails.logger.info "[Agent#bulk_create] ignoring email #{email}, errors: #{e.record.errors}"
      end
    end

    # This endpoint is used to bulk create agents during onboarding
    # onboarding_step key in present in Current account custom attributes, since this is a one time operation
    Current.account.custom_attributes.delete('onboarding_step')
    Current.account.save!
    head :ok
  end

  private

  def check_authorization
    super(User)
  end

  def fetch_agent
    @agent = agents.find(params[:id])
  end

  def account_user_attributes
    [:role, :availability, :auto_offline, :merchant_status, :merchant_expires_at, :agent_limit, :parent_merchant_id]
  end

  def allowed_agent_params
    [
      :name,
      :email,
      :password,
      :password_confirmation,
      :role,
      :availability,
      :auto_offline,
      :merchant_status,
      :merchant_expires_at,
      :agent_limit,
      :parent_merchant_id
    ]
  end

  def agent_params
    params.require(:agent).permit(allowed_agent_params)
  end

  def new_agent_params
    params.require(:agent).permit(*allowed_agent_params)
  end

  def agents
    @agents ||= scoped_agent_users.order_by_full_name.includes(:account_users, { avatar_attachment: [:blob] })
  end

  def validate_limit_for_bulk_create
    return render_payment_required('Bulk create is not available for merchants') if Current.account_user.merchant?

    limit_available = params[:emails].count <= available_agent_count
    render_payment_required('Account limit exceeded. Please purchase more licenses') unless limit_available
  end

  def validate_limit
    if Current.account_user.merchant?
      return render_payment_required('Merchant agent limit exceeded') unless can_add_agent?

      return
    end

    render_payment_required('Account limit exceeded. Please purchase more licenses') unless can_add_agent?
  end

  def available_agent_count
    return Current.account.usage_limits[:agents] - agents.count if Current.account_user.administrator?

    Current.account_user.agent_limit.to_i - merchant_managed_agents_count
  end

  def can_add_agent?
    available_agent_count.positive?
  end

  def merchant_managed_agents_count
    Current.account.account_users.where(parent_merchant_id: Current.account_user.id, role: :agent).count
  end

  def scoped_agent_users
    if Current.account_user.administrator?
      Current.account.users
    elsif Current.account_user.merchant?
      Current.account.users.joins(:account_users).where(account_users: { parent_merchant_id: Current.account_user.id, role: :agent })
    else
      Current.account.users.none
    end
  end

  def filtered_account_user_params
    params_to_update = agent_params.slice(*account_user_attributes).compact

    if Current.account_user.merchant?
      params_to_update[:role] = 'agent'
      params_to_update[:parent_merchant_id] = Current.account_user.id
      params_to_update = params_to_update.except(:merchant_status, :merchant_expires_at, :agent_limit)
    end

    params_to_update
  end

  def filtered_user_params
    agent_params.slice(:name, :password, :password_confirmation).to_h.compact_blank
  end

  def resolved_role
    return 'agent' if Current.account_user.merchant?

    new_agent_params['role']
  end

  def resolved_parent_merchant_id
    return Current.account_user.id if Current.account_user.merchant?

    new_agent_params['parent_merchant_id']
  end

  def delete_user_record(agent)
    DeleteObjectJob.perform_later(agent) if agent.reload.account_users.blank?
  end
end

Api::V1::Accounts::AgentsController.prepend_mod_with('Api::V1::Accounts::AgentsController')
