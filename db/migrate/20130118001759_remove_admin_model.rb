class RemoveAdminModel < ActiveRecord::Migration
  def up
	drop_table :admins
  end

  def down
	create_table :admins
  end
end
