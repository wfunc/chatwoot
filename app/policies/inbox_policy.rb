class InboxPolicy < ApplicationPolicy
  class Scope
    attr_reader :user_context, :user, :scope, :account, :account_user

    def initialize(user_context, scope)
      @user_context = user_context
      @user = user_context[:user]
      @account = user_context[:account]
      @account_user = user_context[:account_user]
      @scope = scope
    end

    def resolve
      user.assigned_inboxes
    end
  end

  def index?
    true
  end

  def show?
    # FIXME: for agent bots, lets bring this validation to policies as well in future
    return true if @user.is_a?(AgentBot)

    Current.user.assigned_inboxes.include? record
  end

  def assignable_agents?
    true
  end

  def agent_bot?
    true
  end

  def campaigns?
    administrator? || merchant_owner?
  end

  def create?
    administrator?
  end

  def update?
    administrator? || merchant_owner?
  end

  def destroy?
    administrator?
  end

  def set_agent_bot?
    administrator? || merchant_owner?
  end

  def avatar?
    administrator? || merchant_owner?
  end

  def sync_templates?
    administrator? || merchant_owner?
  end

  def health?
    administrator? || merchant_owner?
  end

  def reset_secret?
    administrator? || merchant_owner?
  end

  def manage_members?
    administrator? || merchant_owner?
  end

  private

  def merchant_owner?
    merchant? && record.merchant_owner_id == account_user.id
  end
end
