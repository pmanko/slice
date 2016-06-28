class AddUnblindedToProjectUsersAndSiteUsers < ActiveRecord::Migration[4.2]
  def change
    add_column :project_users, :unblinded, :boolean, null: false, default: true
    add_column :site_users, :unblinded, :boolean, null: false, default: true
  end
end
