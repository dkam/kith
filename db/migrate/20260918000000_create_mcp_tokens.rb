class CreateMcpTokens < ActiveRecord::Migration[8.1]
  def change
    create_table :mcp_tokens do |t|
      t.references :member, null: false, foreign_key: true
      t.string :token, null: false
      # What the member calls this endpoint. One per member today; the column
      # is here because "Claude on my phone" and "the laptop" want telling
      # apart the moment there is more than one.
      t.string :name
      # Integer-backed and sparse, like posts.audience: read_only is the only
      # thing phase 1 grants, and a token that may write will be another value
      # rather than another table.
      t.integer :access, null: false, default: 0
      t.datetime :last_used_at

      t.timestamps
    end

    add_index :mcp_tokens, :token, unique: true
  end
end
