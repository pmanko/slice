class RemoveColumnsFromSites < ActiveRecord::Migration
  def change
    remove_column :sites, :prefix, :string, null: false, default: ''
    remove_column :sites, :code_minimum, :string
    remove_column :sites, :code_maximum, :string
  end
end
