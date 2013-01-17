class CreateCityWorkflows < ActiveRecord::Migration
  def change
    create_table :city_workflows do |t|
    	t.integer :city_id
    	t.integer :workflow_id
      t.timestamps
    end
  end
end
