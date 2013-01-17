class City < ActiveRecord::Base
  # attr_accessible :title, :body
  belongs_to :state
  has_many :city_workflows
  has_many :workflows, :through => :city_workflows
end
