class AddMerchantFieldsToAccountUsersAndInboxes < ActiveRecord::Migration[7.1]
  def change
    add_column :account_users, :merchant_status, :integer, default: 0, null: false
    add_column :account_users, :merchant_expires_at, :datetime
    add_column :account_users, :agent_limit, :integer
    add_reference :account_users, :parent_merchant, foreign_key: { to_table: :account_users }, index: true

    add_reference :inboxes, :merchant_owner, foreign_key: { to_table: :account_users }, index: true
  end
end
