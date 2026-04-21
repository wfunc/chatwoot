# == Schema Information
#
# Table name: account_users
#
#  id                       :bigint           not null, primary key
#  active_at                :datetime
#  agent_limit              :integer
#  auto_offline             :boolean          default(TRUE), not null
#  availability             :integer          default("online"), not null
#  merchant_expires_at      :datetime
#  merchant_status          :integer          default("active"), not null
#  role                     :integer          default("agent")
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  account_id               :bigint
#  agent_capacity_policy_id :bigint
#  custom_role_id           :bigint
#  inviter_id               :bigint
#  parent_merchant_id       :bigint
#  user_id                  :bigint
#
# Indexes
#
#  index_account_users_on_account_id                (account_id)
#  index_account_users_on_agent_capacity_policy_id  (agent_capacity_policy_id)
#  index_account_users_on_custom_role_id            (custom_role_id)
#  index_account_users_on_parent_merchant_id        (parent_merchant_id)
#  index_account_users_on_user_id                   (user_id)
#  uniq_user_id_per_account_id                      (account_id,user_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (parent_merchant_id => account_users.id)
#

class AccountUser < ApplicationRecord
  include AvailabilityStatusable

  belongs_to :account
  belongs_to :user
  belongs_to :inviter, class_name: 'User', optional: true
  belongs_to :parent_merchant, class_name: 'AccountUser', optional: true
  has_many :managed_account_users, class_name: 'AccountUser', foreign_key: :parent_merchant_id, dependent: :nullify, inverse_of: :parent_merchant
  has_many :merchant_owned_inboxes, class_name: 'Inbox', foreign_key: :merchant_owner_id, dependent: :nullify, inverse_of: :merchant_owner

  enum role: { agent: 0, administrator: 1, merchant: 2 }
  enum availability: { online: 0, offline: 1, busy: 2 }
  enum merchant_status: { active: 0, suspended: 1, expired: 2 }

  accepts_nested_attributes_for :account

  after_create_commit :notify_creation, :create_notification_setting
  after_destroy :notify_deletion, :remove_user_from_account
  after_save :update_presence_in_redis, if: :saved_change_to_availability?

  validates :user_id, uniqueness: { scope: :account_id }
  validates :agent_limit, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validate :validate_parent_merchant
  validate :validate_merchant_fields

  def create_notification_setting
    setting = user.notification_settings.new(account_id: account.id)
    setting.selected_email_flags = [:email_conversation_assignment]
    setting.selected_push_flags = [:push_conversation_assignment]
    setting.save!
  end

  def remove_user_from_account
    ::Agents::DestroyJob.perform_later(account, user)
  end

  def permissions
    return ['administrator'] if administrator?
    return ['merchant'] if merchant?

    ['agent']
  end

  def merchant_owner
    return self if merchant?

    parent_merchant
  end

  def merchant_owner_id_for_scope
    merchant_owner&.id
  end

  def merchant_managed?
    merchant_owner.present?
  end

  def active_for_dashboard?
    return true unless merchant? || merchant_managed?

    merchant_state == 'active'
  end

  def merchant_state
    owner = merchant_owner
    return 'active' if owner.blank?
    return 'expired' if owner.merchant_expires_at.present? && owner.merchant_expires_at <= Time.current

    owner.merchant_status
  end

  def days_until_merchant_expiry
    owner = merchant_owner
    return nil if owner.blank? || owner.merchant_expires_at.blank?

    ((owner.merchant_expires_at.to_date - Time.zone.today).to_i).clamp(0, Float::INFINITY)
  end

  def expiring_soon?(threshold_days = 3)
    days_remaining = days_until_merchant_expiry
    days_remaining.present? && days_remaining <= threshold_days
  end

  def can_manage_agent?(other_account_user)
    return true if administrator?

    merchant? && other_account_user.agent? && other_account_user.parent_merchant_id == id
  end

  def can_manage_inbox?(inbox)
    return true if administrator?

    merchant? && inbox.merchant_owner_id == id
  end

  def push_event_data
    {
      id: id,
      availability: availability,
      role: role,
      user_id: user_id
    }
  end

  private

  def validate_parent_merchant
    return if parent_merchant_id.blank?
    return errors.add(:parent_merchant, 'must belong to the same account') if parent_merchant&.account_id != account_id
    return errors.add(:parent_merchant, 'must be a merchant') unless parent_merchant&.merchant?
    return errors.add(:parent_merchant, 'can only be assigned to agents') unless agent?
    return errors.add(:parent_merchant, 'cannot manage itself') if parent_merchant_id == id
  end

  def validate_merchant_fields
    return unless merchant?

    errors.add(:agent_limit, 'must be present for merchants') if agent_limit.blank?
  end

  def notify_creation
    Rails.configuration.dispatcher.dispatch(AGENT_ADDED, Time.zone.now, account: account)
  end

  def notify_deletion
    Rails.configuration.dispatcher.dispatch(AGENT_REMOVED, Time.zone.now, account: account)
  end

  def update_presence_in_redis
    OnlineStatusTracker.set_status(account.id, user.id, availability)
  end
end

AccountUser.prepend_mod_with('AccountUser')
AccountUser.include_mod_with('Audit::AccountUser')
AccountUser.include_mod_with('Concerns::AccountUser')
