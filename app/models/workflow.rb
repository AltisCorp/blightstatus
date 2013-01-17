class Workflow < ActiveRecord::Base
  # attr_accessible :title, :body
  has_many :city_workflows
  has_many :cities, :through => :city_workflows
end
