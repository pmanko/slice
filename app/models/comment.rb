# frozen_string_literal: true

# Allows editors and viewers to comment on sheets.
class Comment < ApplicationRecord
  # Concerns
  include Deletable
  include Searchable

  # Callbacks
  after_create_commit :create_notifications

  # Validations
  validates :description, :sheet_id, :user_id, presence: true

  # Relationships
  belongs_to :user
  belongs_to :sheet, counter_cache: true
  has_many :notifications

  delegate :project, to: :sheet
  delegate :project_id, to: :sheet
  delegate :users, to: :sheet
  delegate :editable_by?, to: :sheet

  # Scopes
  def self.with_project(arg)
    joins(:sheet).merge(Sheet.current.where(project_id: arg))
  end

  # Methods

  def event_at
    created_at
  end

  def name
    "##{id}"
  end

  def number
    (sheet.comments.reorder(:id).pluck(:id).index(id) || -1) + 1
  end

  def anchor
    "comment-#{number}"
  end

  def deletable_by?(current_user)
    user == current_user || editable_by?(current_user)
  end

  def self.searchable_attributes
    %w(description)
  end

  def destroy
    super
    notifications.destroy_all
    Sheet.reset_counters(sheet_id, :comments)
  end

  private

  def create_notifications
    users.where.not(id: user.id).each do |u|
      u.notifications.create(project_id: project_id, comment_id: id)
    end
    true
  end
end
