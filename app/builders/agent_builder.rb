# The AgentBuilder class is responsible for creating a new agent.
# It initializes with necessary attributes and provides a perform method
# to create a user and account user in a transaction.
class AgentBuilder
  # Initializes an AgentBuilder with necessary attributes.
  # @param email [String] the email of the user.
  # @param name [String] the name of the user.
  # @param role [String] the role of the user, defaults to 'agent' if not provided.
  # @param inviter [User] the user who is inviting the agent (Current.user in most cases).
  # @param availability [String] the availability status of the user, defaults to 'offline' if not provided.
  # @param auto_offline [Boolean] the auto offline status of the user.
  pattr_initialize [
    :email,
    { name: '' },
    :inviter,
    :account,
    { role: :agent },
    { availability: :online },
    { auto_offline: false },
    { merchant_status: :active },
    { merchant_expires_at: nil },
    { agent_limit: nil },
    { parent_merchant_id: nil },
    { max_active_clients: nil },
    { password: nil },
    { password_confirmation: nil }
  ]

  # Creates a user and account user in a transaction.
  # @return [User] the created user.
  def perform
    ActiveRecord::Base.transaction do
      @user = find_or_create_user
      create_account_user
    end
    @user
  end

  private

  # Finds a user by email or creates a new one with a temporary password.
  # @return [User] the found or created user.
  def find_or_create_user
    user = User.from_email(email)
    return user if user

    resolved_password = password.presence || "1!aA#{SecureRandom.alphanumeric(12)}"
    resolved_password_confirmation = password_confirmation.presence || resolved_password

    User.create!(
      email: email,
      name: name,
      max_active_clients: max_active_clients,
      password: resolved_password,
      password_confirmation: resolved_password_confirmation
    )
  end

  # Checks if the user needs confirmation.
  # @return [Boolean] true if the user is persisted and not confirmed, false otherwise.
  def user_needs_confirmation?
    @user.persisted? && !@user.confirmed?
  end

  # Creates an account user linking the user to the current account.
  def create_account_user
    AccountUser.create!({
      account_id: account.id,
      user_id: @user.id,
      inviter_id: inviter.id
    }.merge({
      role: role,
      availability: availability,
      auto_offline: auto_offline,
      merchant_status: merchant_status,
      merchant_expires_at: merchant_expires_at,
      agent_limit: agent_limit,
      parent_merchant_id: parent_merchant_id
    }.compact))
  end
end

AgentBuilder.prepend_mod_with('AgentBuilder')
