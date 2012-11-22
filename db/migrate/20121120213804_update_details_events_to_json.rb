class UpdateDetailsEventsToJson < ActiveRecord::Migration
  def up
  	change_column :events, :details, :string
  end

  def down
  	change_column :events, :details, hstore
  end
end
