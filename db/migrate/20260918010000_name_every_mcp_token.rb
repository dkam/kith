# Endpoints came one to a member and unnamed. Now that a member can hold
# several — a reader on the phone, something that writes on the desktop — the
# name is how they are told apart, so it stops being optional.
class NameEveryMcpToken < ActiveRecord::Migration[8.1]
  def up
    execute "UPDATE mcp_tokens SET name = 'Endpoint' WHERE name IS NULL OR name = ''"
    change_column_null :mcp_tokens, :name, false
  end

  def down
    change_column_null :mcp_tokens, :name, true
  end
end
