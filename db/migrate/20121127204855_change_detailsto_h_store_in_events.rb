class ChangeDetailstoHStoreInEvents < ActiveRecord::Migration
  def up
  	add_column :events, :dhash, :text
  	add_column :events, :dstore, :hstore

  	execute "CREATE INDEX events_gin_dstore ON events USING GIN(dstore)"
  end

  def down
  	remove_column :events, :dhash
  	remove_column :events, :store
  end
end
