class Event < ActiveRecord::Base
  serialize :dstore, ActiveRecord::Coders::Hstore
  serialize :dhash, Hash
  
  attr_protected :dstore
  belongs_to :case, :foreign_key => :case_number, :primary_key => :case_number
  validates_uniqueness_of :date, :scope => [:case_number, :name]

  before_save :update_dstore

  def update_dstore
    self.dstore = self.dhash
  end 
end
