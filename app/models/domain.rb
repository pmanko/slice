# frozen_string_literal: true

# Represents a finite set of options for a given variable.
class Domain < ApplicationRecord
  # Concerns
  include Deletable
  include Searchable

  attr_accessor :option_tokens

  # Validations
  validates :name, :display_name, :project_id, :user_id, presence: true
  validates :name, format: { with: /\A[a-z]\w*\Z/i },
                   length: { maximum: 30 },
                   uniqueness: { scope: [:deleted, :project_id] }

  # Relationships
  belongs_to :user
  belongs_to :project
  has_many :domain_options, -> { order("position nulls last", :id) }
  has_many :variables, -> { current }
  has_many :sheet_variables, through: :variables
  has_many :grids, through: :variables
  has_many :responses, through: :variables

  # Methods

  def self.searchable_attributes
    %w(name description)
  end

  def missing_codes?
    domain_options.where(missing_code: true).count > 0
  end

  def descriptions?
    domain_options.where.not(description: [nil, ""]).count > 0
  end

  def sites?
    domain_options.where.not(site_id: nil).count > 0
  end

  def archived_options?
    domain_options.where(archived: true).count > 0
  end

  # Returns true if all options are integers
  # TODO: Check where this is referenced for optimization
  # TODO: Currently doesn't allow decimals.
  def all_numeric?
    @all_numeric ||= begin
      domain_options.pluck(:value).count { |v| !(v =~ /^[-+]?[0-9]+$/) }.zero?
    end
  end

  def sas_value_domain
    "  value #{sas_domain_name}\n#{domain_options.collect { |o| "    #{"'" unless all_numeric? }#{o.value}#{"'" unless all_numeric?}='#{o.value}: #{o.name.gsub("'", "''")}'" }.join("\n")}\n  ;"
  end

  def sas_domain_name
    "#{'$' unless all_numeric?}#{name}f"
  end

  def self.clean_option_tokens(params)
    (params[:option_tokens] || []).each_with_index do |option, index|
      params[:option_tokens][index][:value] = (index + 1).to_s if option[:name].present? && option[:value].blank?
    end
    params
  end

  def update_option_tokens!
    return if option_tokens.nil?
    domain_option_ids = option_tokens.collect { |hash| hash[:domain_option_id] }.select(&:present?)
    domain_options.where.not(id: domain_option_ids).destroy_all
    option_tokens.each_with_index do |option_hash, index|
      next if option_hash[:name].blank?
      domain_option = domain_options.find_by(id: option_hash.delete(:domain_option_id))
      if domain_option
        if domain_option.update(cleaned_hash(option_hash, index, domain_option))
          domain_option.add_domain_option!
        end
      else
        domain_option = domain_options.create(cleaned_hash(option_hash, index, nil))
        domain_option.add_domain_option! unless domain_option.new_record?
      end
    end
  end

  def cleaned_hash(option_hash, index, domain_option)
    description = DesignOption.cleaned_description(option_hash, domain_option)
    value = DesignOption.cleaned_value(option_hash, index)
    {
      name: option_hash[:name], value: value, description: description,
      site_id: option_hash[:site_id], position: index,
      missing_code: (option_hash[:missing_code] == "1"),
      archived: (option_hash[:archived] == "1")
    }
  end

  def add_domain_values!
    domain_options.each(&:add_domain_option!)
  end

  def remove_domain_values!
    domain_options.each(&:remove_domain_option!)
  end
end
