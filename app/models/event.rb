class Event < ActiveRecord::Base
  #serialize :details, ActiveRecord::Coders::Hstore
  serialize :details, JSON
  belongs_to :case, :foreign_key => :case_number, :primary_key => :case_number
  validates_uniqueness_of :date, :scope => [:case_number, :name]

  after_initialize :init_dhash
  before_save :save_details
  attr_accessor	 :dhash
  def init_dhash
  	d_str = self.details
  	if d_str
    	@dhash = JSON.parse(d_str) #JSON.parse(read_attribute(:details)) # if column_name is the name of the column
	else
		@dhash = {}
	end
  end

  def save_details
    #write_attribute(:details, @dhash.to_json)  # or you can modify value, and call super with it. Search on Internet to find more.
    self.details = @dhash.to_json
  end
end
