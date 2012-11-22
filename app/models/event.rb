class Event < ActiveRecord::Base
  #serialize :details, ActiveRecord::Coders::Hstore
  serialize :details, JSON
  attr_protected :details
  belongs_to :case, :foreign_key => :case_number, :primary_key => :case_number
  validates_uniqueness_of :date, :scope => [:case_number, :name]

  after_initialize :init_dhash
  before_save :set_details
  attr_accessor	 :dhash
  def init_dhash
  	d_str = self.details
  	if d_str
    	@dhash = JSON.parse(d_str)
	else
		@dhash = {}
	end
  end

  def set_details
    self.details = @dhash.to_json
  end
end
