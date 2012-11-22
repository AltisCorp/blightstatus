class AddDetailsToCases < ActiveRecord::Migration
  def change
  	add_column :cases, :details, :text
  end
end
