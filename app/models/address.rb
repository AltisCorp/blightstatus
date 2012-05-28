class Address < ActiveRecord::Base
  belongs_to :street
  has_many :cases
  has_many :demolitions
  has_many :foreclosures
  has_many :maintenances

  has_many :inspections, :through => :cases
  has_many :notifications, :through => :cases
  has_many :hearings, :through => :cases
  has_many :judgements, :through => :cases

  validates_uniqueness_of :address_id

  self.per_page = 50

  def workflow_steps
    steps_ary = []
    self.cases.each do |c|
      steps_ary << c.accela_steps
    end
    steps_ary << self.resolutions
    steps_ary.flatten.compact
  end

  def resolutions
    res_ary = []
    res_ary << self.foreclosures << self.demolitions << self.maintenances
    res_ary.flatten.compact
  end

  def most_recent_status
    !self.workflow_steps.empty? ? self.workflow_steps.sort{ |a, b| a.date <=> b.date }.last : nil
  end

  def sorted_cases
    self.cases.sort{ |a, b| a.most_recent_status.date <=> b.most_recent_status.date }
  end

  def most_recent_status_preview
    s = self.most_recent_status
    {:type => s.class.to_s, :date => s.date.strftime('%B %e, %Y')}
  end

  def self.find_addresses_with_cases_by_street(street_string)
    Address.joins(:cases).where(:addresses => {:street_name => street_string})
  end

end
