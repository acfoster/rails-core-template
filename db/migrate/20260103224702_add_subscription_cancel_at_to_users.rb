class AddSubscriptionCancelAtToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :subscription_cancel_at, :datetime
  end
end
