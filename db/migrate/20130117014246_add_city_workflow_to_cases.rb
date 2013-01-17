class AddCityWorkflowToCases < ActiveRecord::Migration
  def change
  	add_column :cases, :city_workflow_id, :integer
  end
end
