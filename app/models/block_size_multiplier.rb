class BlockSizeMultiplier < ActiveRecord::Base
  # Concerns
  include Deletable

  # Named Scopes

  # Model Validation
  validates :user_id, :project_id, :randomization_scheme_id, presence: true
  validates :value, uniqueness: { scope: [:deleted, :project_id, :randomization_scheme_id] }
  validates :value, numericality: { greater_than_or_equal_to: 1, only_integer: true }
  validates :allocation, numericality: { greater_than_or_equal_to: 0, only_integer: true }

  # Model Relationships
  belongs_to :user
  belongs_to :project
  belongs_to :randomization_scheme

  # Model Methods

  def name
    "x#{value}"
  end
end
