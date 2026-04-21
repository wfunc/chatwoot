class CustomFilterPolicy < ApplicationPolicy
  def create?
    @account_user.administrator? || @account_user.agent? || @account_user.merchant?
  end

  def show?
    @account_user.administrator? || @account_user.agent? || @account_user.merchant?
  end

  def index?
    @account_user.administrator? || @account_user.agent? || @account_user.merchant?
  end

  def update?
    @account_user.administrator? || @account_user.agent? || @account_user.merchant?
  end

  def destroy?
    @account_user.administrator? || @account_user.agent? || @account_user.merchant?
  end
end
