# frozen_string_literal: true

class Site < ActiveRecord::Base
  # Concerns
  include Searchable, Deletable

  # Named Scopes
  scope :with_project, -> (arg) { where(project_id: arg) }
  scope :with_project_or_as_site_user, -> (*args) { where('sites.project_id IN (?) or sites.id in (select site_users.site_id from site_users where site_users.user_id = ?)', args.first, args[1]).references(:site_users) }
  scope :with_project_or_as_site_editor, -> (*args) { where('sites.project_id IN (?) or sites.id in (select site_users.site_id from site_users where site_users.user_id = ? and site_users.editor = ?)', args.first, args[1], true).references(:site_users) }

  # Model Validation
  validates :name, :project_id, :user_id, presence: true
  validates :name, uniqueness: { scope: [:project_id, :deleted] }
  validates :subject_code_format, format: { with: /\A((\\d)|(\\l)|(\\L)|[a-zA-Z0-9])*\Z/ }, allow_blank: true

  # Model Relationships
  belongs_to :user
  belongs_to :project
  has_many :subjects, -> { where deleted: false }
  has_many :site_users
  has_many :users, -> { where(deleted: false).order('last_name, first_name') }, through: :site_users

  def regex_string
    subject_code_format.to_s.gsub('\d', '[0-9]').gsub('\l', '[a-z]').gsub('\L', '[A-Z]')
  end

  def subject_regex
    Regexp.new("\\A#{regex_string}\\Z") if regex_string.present?
  end
end
