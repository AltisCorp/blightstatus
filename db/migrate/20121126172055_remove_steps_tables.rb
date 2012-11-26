class RemoveStepsTables < ActiveRecord::Migration
  def up
  	drop_table :complaints
  	drop_table :inspections
  	drop_table :notifications
  	drop_table :hearings
  	drop_table :judgements
  	drop_table :resets
  	drop_table :demolitions
  	drop_table :maintenances
  	drop_table :foreclosures
  end

end
