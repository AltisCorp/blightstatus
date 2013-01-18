class AddressCityToMunipality < ActiveRecord::Migration
  def up
  	rename_column :addresses, :city_id, :municipality_id
  end

  def down
  	rename_column :addresses , :municipality_id, :city_id
  end
end
