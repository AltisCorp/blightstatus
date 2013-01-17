class CityWorkflow < ActiveRecord::Base
  # attr_accessible :title, :body
  belongs_to :city
  belongs_to :workflow
  has_many :cases
end
