class RenameAccounts < ActiveRecord::Migration
  def up
	rename_table :accounts, :users
  end

  def down
	rename_table :users, :accounts  	
  end
end
