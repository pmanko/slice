class AddAuthenticationTokenToSheets < ActiveRecord::Migration[4.2]
  def change
    add_column :sheets, :authentication_token, :string
    add_index :sheets, :authentication_token, unique: true
  end
end
