class CreateComments < ActiveRecord::Migration[8.1]
  def change
    create_table :comments do |t|
      t.references :post, null: false, foreign_key: true
      t.references :actor, null: false, foreign_key: true
      t.text :body, null: false

      t.timestamps
    end

    add_index :comments, [ :post_id, :created_at ]
  end
end
