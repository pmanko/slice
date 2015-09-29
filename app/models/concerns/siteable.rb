module Siteable
  extend ActiveSupport::Concern

  included do
    def self.with_site(arg)
      # The merge is preferred, however does not work with buildable.rb at the
      # moment
      # joins(:subject).merge(Subject.current.where(site_id: arg))
      joins(:subject).where(subjects: { deleted: false, site_id: arg })
    end
  end
end