class AddMaxActiveClientsToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :max_active_clients, :integer
  end
end
