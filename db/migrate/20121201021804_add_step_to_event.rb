class AddStepToEvent < ActiveRecord::Migration
  def change
  	add_column :events, :step, :string
  end
end
