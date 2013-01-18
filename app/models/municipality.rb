class Municipality < ActiveRecord::Base
  # attr_accessible :title, :body
  belongs_to :state
  has_many :municipality_workflows
  has_many :workflows, :through => :municipality_workflows
  has_many :addresses
end
