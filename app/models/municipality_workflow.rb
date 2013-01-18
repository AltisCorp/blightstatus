class MunicipalityWorkflow < ActiveRecord::Base
  # attr_accessible :title, :body
  belongs_to :municipality
  belongs_to :workflow
  has_many :cases
end
