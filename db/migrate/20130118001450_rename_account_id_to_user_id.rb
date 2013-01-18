class RenameAccountIdToUserId < ActiveRecord::Migration
  def up
    rename_column :subscriptions, :account_id, :user_id
  end

  def down
    rename_column :subscriptions, :user_id, :account_id
  end
end
