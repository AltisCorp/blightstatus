class RemoveIntakeFromCases < ActiveRecord::Migration
  def up
  	remove_column :cases, :intake
  end

  def down
  end
end
