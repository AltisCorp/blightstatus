class AddCaseNumberToEvents < ActiveRecord::Migration
  def up
  	add_column :events, :case_number, :string
  end
  def down
  	remove_column :events, :case_number
  end
end
