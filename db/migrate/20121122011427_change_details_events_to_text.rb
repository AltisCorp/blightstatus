class ChangeDetailsEventsToText < ActiveRecord::Migration
  def down
  	change_column :events, :details, :string
  end

  def up
  	change_column :events, :details, :text
  end
end
