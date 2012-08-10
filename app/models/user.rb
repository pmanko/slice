class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :confirmable, :lockable and :omniauthable
  devise :database_authenticatable, :registerable, :timeoutable,
         :recoverable, :rememberable, :trackable, :validatable, :token_authenticatable

  # Setup accessible (or protected) attributes for your model
  attr_accessible :email, :password, :password_confirmation, :remember_me  # attr_accessible :title, :body
  attr_accessible :first_name, :last_name, :pagination

  serialize :pagination, Hash

  # Callbacks
  after_create :notify_system_admins

  STATUS = ["active", "denied", "inactive", "pending"].collect{|i| [i,i]}

  # Named Scopes
  scope :current, conditions: { deleted: false }
  scope :human, conditions: { } # Placeholder
  scope :status, lambda { |*args|  { conditions: ["users.status IN (?)", args.first] } }
  scope :search, lambda { |*args| { conditions: [ 'LOWER(first_name) LIKE ? or LOWER(last_name) LIKE ? or LOWER(email) LIKE ?', '%' + args.first.downcase.split(' ').join('%') + '%', '%' + args.first.downcase.split(' ').join('%') + '%', '%' + args.first.downcase.split(' ').join('%') + '%' ] } }
  scope :system_admins, conditions: { system_admin: true }
  scope :librarians, conditions: { librarian: true }
  scope :with_sheet, lambda { |*args| { conditions: ["users.id in (select DISTINCT(sheets.user_id) from sheets where sheets.deleted = ?)", false] }  }
  scope :with_design, lambda { |*args| { conditions: ["users.id in (select DISTINCT(designs.user_id) from designs where designs.deleted = ?)", false] }  }
  scope :with_variable, lambda { |*args| { conditions: ["users.id in (select DISTINCT(variables.user_id) from variables where variables.deleted = ?)", false] }  }

  # Model Validation
  validates_presence_of :first_name, :last_name

  # Model Relationships
  has_many :authentications
  has_many :designs, conditions: { deleted: false }
  has_many :projects, conditions: { deleted: false }
  has_many :sheets, conditions: { deleted: false }
  has_many :sites, conditions: { deleted: false }
  has_many :subjects, conditions: { deleted: false }
  has_many :variables, conditions: { deleted: false }

  # User Methods

  def pagination_count(model)
    self.pagination[model.to_s].to_i > 0 ? self.pagination[model.to_s].to_i : 25
  end

  def pagination_set!(model, count)
    original_pagination = self.pagination
    original_pagination[model.to_s] = count
    self.update_attributes pagination: original_pagination
  end

  def all_projects
    @all_projects ||= begin
      Project.current.with_librarian(self.id, true)
    end
  end

  def all_viewable_projects
    @all_viewable_projects ||= begin
      Project.current.with_librarian(self.id, [true, false])
    end
  end

  def all_designs
    @all_designs ||= begin
      if self.librarian?
        Design.current.with_project_or_global(self.all_projects.pluck(:id))
      else
        Design.current.with_project(self.all_projects.pluck(:id))
      end
    end
  end

  def all_viewable_designs
    @all_viewable_designs ||= begin
      Design.current.with_project_or_global(self.all_viewable_projects.pluck(:id))
    end
  end

  def all_variables
    @all_variables ||= begin
      if self.librarian?
        Variable.current.with_project_or_global(self.all_projects.pluck(:id))
      else
        Variable.current.with_project(self.all_projects.pluck(:id))
      end
    end
  end

  def all_viewable_variables
    @all_viewable_variables ||= begin
      Variable.current.with_project_or_global(self.all_viewable_projects.pluck(:id))
    end
  end

  # Project Librarians and Members can modify sheets
  def all_sheets
    @all_sheets ||= begin
      Sheet.current.with_project(self.all_viewable_projects.pluck(:id))
    end
  end

  # Project Librarians and Members and Site Members can modify sheets
  def all_viewable_sheets
    @all_viewable_sheets ||= begin
      Sheet.current.with_site(self.all_viewable_sites.pluck(:id))
    end
  end

  # Project Librarians
  def all_sites
    @all_sites ||= begin
      Site.current.with_project(self.all_projects.pluck(:id))
    end
  end

  # Project Librarians and Members and Site Members
  def all_viewable_sites
    @all_viewable_sites ||= begin
      Site.current.with_project_or_as_site_user(self.all_viewable_projects.pluck(:id), self)
    end
  end

  # Project Librarians and Members can modify subjects
  def all_subjects
    Subject.current.with_project(self.all_viewable_projects.pluck(:id))
  end

  # Project Librarians and Members can view subjects
  def all_viewable_subjects
    @all_viewable_subjects ||= begin
      Subject.current.with_site(self.all_viewable_sites.pluck(:id))
    end
  end

  # Overriding Devise built-in active_for_authentication? method
  def active_for_authentication?
    super and self.status == 'active' and not self.deleted?
  end

  def destroy
    update_column :deleted, true
    update_column :status, 'inactive'
    update_column :updated_at, Time.now
  end

  # def email_on?(value)
  #   [nil, true].include?(self.email_notifications[value.to_s])
  # end

  def name
    "#{first_name} #{last_name}"
  end

  def reverse_name
    "#{last_name}, #{first_name}"
  end

  def apply_omniauth(omniauth)
    unless omniauth['info'].blank?
      self.email = omniauth['info']['email'] if email.blank?
      self.first_name = omniauth['info']['first_name'] if first_name.blank?
      self.last_name = omniauth['info']['last_name'] if last_name.blank?
    end
    authentications.build( provider: omniauth['provider'], uid: omniauth['uid'] )
  end

  def password_required?
    (authentications.empty? || !password.blank?) && super
  end

  private

  def notify_system_admins
    User.current.system_admins.each do |system_admin|
      UserMailer.notify_system_admin(system_admin, self).deliver if Rails.env.production?
    end
  end
end
