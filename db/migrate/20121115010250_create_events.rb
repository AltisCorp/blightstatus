class CreateEvents < ActiveRecord::Migration
  def change
    create_table :events do |t|
      t.string :name
      t.datetime :date
      t.integer :status
      t.hstore :details
      
      t.timestamps
    end
  end
end
