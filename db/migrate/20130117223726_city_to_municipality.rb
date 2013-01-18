class CityToMunicipality < ActiveRecord::Migration
  def up
  	rename_table :cities, :municipalities
  	rename_table :city_workflows, :municipality_workflows

  	rename_column :cases, :city_workflow_id, :municipality_workflow_id
  	rename_column :municipality_workflows, :city_id, :municipality_id
  	add_column :addresses, :city_id, :integer
  end

  def down
  	remove_column :addresses, :city_id
  end
end
