class AddPrincipalReviewerToAeReviewTeamMembers < ActiveRecord::Migration[5.2]
  def change
    add_column :ae_review_team_members, :principal_reviewer, :boolean, null: false, default: false
    add_index :ae_review_team_members, :principal_reviewer
  end
end
