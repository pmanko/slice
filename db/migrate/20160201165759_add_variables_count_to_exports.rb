class AddVariablesCountToExports < ActiveRecord::Migration[4.2]
  def change
    add_column :exports, :variables_count, :integer, null: false, default: 0
  end
end
