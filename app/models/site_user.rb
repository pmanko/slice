class SiteUser < ActiveRecord::Base
  attr_accessible :creator_id, :site_id, :user_id, :project_id, :invite_email, :invite_token

  # Named Scopes
  scope :current, conditions: { }

  # Model Validation
  validates_presence_of :creator_id, :site_id, :project_id #, :user_id
  validates_uniqueness_of :invite_token, allow_nil: true

  # Model Relationships
  belongs_to :creator, class_name: 'User', foreign_key: 'creator_id'
  belongs_to :project
  belongs_to :user
  belongs_to :site

  after_create :send_invitation

  def send_invitation
    self.generate_invite_token!
  end

  def generate_invite_token!(invite_token = SecureRandom.hex(64))
    self.update_attributes invite_token: invite_token if self.respond_to?('invite_token') and self.invite_token.blank? and SiteUser.where(invite_token: invite_token).count == 0
    UserMailer.invite_user_to_site(self).deliver if Rails.env.production? and not self.invite_token.blank?
  end

end
