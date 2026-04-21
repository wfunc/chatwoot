class UserPolicy < ApplicationPolicy
  def index?
    true
  end

  def create?
    administrator? || merchant?
  end

  def update?
    administrator? || merchant?
  end

  def destroy?
    administrator? || merchant?
  end

  def bulk_create?
    administrator? || merchant?
  end
end
