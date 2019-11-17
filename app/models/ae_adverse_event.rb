# frozen_string_literal: true

class AeAdverseEvent < ApplicationRecord
  # Constants
  DOCS_PER_PAGE = 20

  # Concerns
  include Blindable
  include Deletable
  include Forkable
  include Siteable
  include Squishable

  squish :description

  # Validations
  validates :description, presence: true

  # Relationships
  belongs_to :project
  belongs_to :user
  belongs_to :subject
  belongs_to :closer, class_name: "User", foreign_key: "closer_id", optional: true
  has_many :ae_log_entries, -> { order(:created_at) }
  has_many :ae_info_requests
  has_many :ae_adverse_event_teams, -> { order(:ae_team_id) }
  has_many :ae_teams, through: :ae_adverse_event_teams
  has_many :ae_assignments, -> { current }
  has_many :ae_documents
  has_many :ae_sheets
  has_many :sheets, -> { current }

  def current_and_deleted_assignments
    ae_assignments.unscope(where: :deleted)
  end

  # Methods
  def reported_by
    user.full_name
  end

  def sort_event_date
    created_at
  end

  def event_date_to_s
    sort_event_date ? sort_event_date.strftime("%a, %b %-d, %Y") : "No Date"
  end

  def event_date_to_s_xs
    sort_event_date ? sort_event_date.strftime("%b %-d, %Y") : "No Date"
  end

  def name
    "AE##{number || "???"}"
  end

  def generate_number!
    update number: adverse_event_number
  end

  def adverse_event_number
    self.class.where(project: project).order(:created_at).pluck(:id).index(id)&.send(:+, 1)
  end

  def historical_events
    subject.ae_adverse_events
  end

  def sent_for_review?
    !sent_for_review_at.nil?
  end

  def closed?
    !closed_at.nil?
  end

  def open?
    !closed?
  end

  def subject_code
    subject&.subject_code
  end

  def subject_code=(code)
    s = project.subjects.find_by "LOWER(subject_code) = ?", code.to_s.downcase
    self.subject_id = (s ? s.id : nil)
  end

  # Logs and notifications
  def opened!(current_user)
    update(number: adverse_event_number, reported_at: created_at)
    ae_log_entries.create(project: project, user: current_user, entry_type: "ae_opened")
    # TODO: AE Notifications
    #   @adverse_event.create_notifications
    send_ae_opened_emails_to_review_admins_in_background!
  end

  def attach_files!(files, current_user)
    documents = []
    files.each do |file|
      next unless file

      document = ae_documents.create(
        project: project,
        user: current_user,
        file: file,
        byte_size: file.size,
        filename: file.original_filename,
        content_type: AeDocument.content_type(file.original_filename)
      )

      documents << document if document.persisted?
    end

    return if documents.blank?

    ae_log_entries.create(
      project: project,
      user: current_user,
      entry_type: "ae_document_uploaded",
      documents: documents
    )
  end

  def sent_for_review!(current_user)
    update sent_for_review_at: Time.zone.now
    ae_log_entries.create(
      project: project,
      user: current_user,
      entry_type: "ae_sent_for_review"
    )
    send_ae_sent_for_review_emails_to_review_admins_in_background!
  end

  def assign_team!(current_user, team)
    ae_adverse_event_teams.where(project: project, ae_team: team).first_or_create
    ae_log_entries.create(project: project, user: current_user, entry_type: "ae_team_assigned", ae_team: team)
    # TODO: Generate in app notifications and LOG notifications for assignment to team (notify team managers, in this case team managers)
  end

  def close!(current_user)
    update(closed_at: Time.zone.now, closer: current_user)
    ae_log_entries.create(project: project, user: current_user, entry_type: "ae_closed")
  end

  def reopen!(current_user)
    update(closed_at: nil, closer: nil)
    ae_log_entries.create(project: project, user: current_user, entry_type: "ae_reopened")
  end

  def next_design_to_complete(role)
    roles_sheets = ae_sheets.where(role: role)
    project.ae_designs(role).each do |design|
      sheet = sheets.where(id: roles_sheets.select(:sheet_id)).find_by(design: design)
      return design if sheet.blank?
    end
    nil
  end

  def roles(current_user)
    all_roles = []
    all_roles << ["reporter", nil] if project.site_or_project_editor?(current_user)
    all_roles << ["admin", nil] if project.ae_admin?(current_user)
    ae_teams.each do |team|
      all_roles << ["manager", team] if project.ae_team_manager?(current_user, team: team)
      all_roles << ["principal_reviewer", team] if project.ae_team_principal_reviewer?(current_user, team: team)
      all_roles << ["reviewer", team] if project.ae_team_reviewer?(current_user, team: team)
      all_roles << ["viewer", team] if project.ae_team_viewer?(current_user, team: team)
    end
    all_roles
  end

  def send_ae_opened_emails_to_review_admins_in_background!
    fork_process(:send_ae_opened_emails_to_review_admins!)
  end

  def send_ae_opened_emails_to_review_admins!
    return if !EMAILS_ENABLED || project.disable_all_emails?

    project.ae_review_admins.each do |review_admin|
      AeAdverseEventMailer.opened(self, review_admin.user).deliver_now
    end
  end

  def send_ae_sent_for_review_emails_to_review_admins_in_background!
    fork_process(:send_ae_sent_for_review_emails_to_review_admins!)
  end

  def send_ae_sent_for_review_emails_to_review_admins!
    return if !EMAILS_ENABLED || project.disable_all_emails?

    project.ae_review_admins.each do |review_admin|
      AeAdverseEventMailer.sent_for_review(self, review_admin.user).deliver_now
    end
  end
end
