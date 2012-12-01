class AddIntakeToCase < ActiveRecord::Migration
  def change
  	add_column :cases, :intake, :datetime
  end
end
