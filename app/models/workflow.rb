class Workflow < ActiveRecord::Base
  # attr_accessible :title, :body
  has_many :munipality_workflows
  has_many :municipalities, :through => :municipality_workflows
end
