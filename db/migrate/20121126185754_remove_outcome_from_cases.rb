class RemoveOutcomeFromCases < ActiveRecord::Migration
  def up
  	remove_column :cases, :outcome
  end

  def down
  end
end
