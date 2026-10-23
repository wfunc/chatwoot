class AddGreetingModeToInboxes < ActiveRecord::Migration[7.1]
  def change
    add_column :inboxes, :greeting_mode, :string, default: 'first_message', null: false
  end
end
