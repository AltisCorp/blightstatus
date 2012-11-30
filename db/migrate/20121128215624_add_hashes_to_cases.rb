class AddHashesToCases < ActiveRecord::Migration
  def change
  	remove_column :cases, :details
  	add_column :cases, :dhash, :text
  	add_column :cases, :dstore, :hstore

  	execute "CREATE INDEX cases_gin_dstore ON cases USING GIN(dstore)"
  end
end
