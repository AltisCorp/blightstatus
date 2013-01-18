class CreatePages < ActiveRecord::Migration
  def change
    create_table :pages do |t|
			t.integer :site_id
			t.string :slug
			t.string :title
			t.string :template
			t.text :body
			t.timestamps			
    end

		# add_index :pages, :slug, unique: true

  end
end
