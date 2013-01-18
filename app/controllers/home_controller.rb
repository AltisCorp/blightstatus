require 'rgeo/geo_json'

class HomeController < ApplicationController
  respond_to :html, :json
  autocomplete :addresses, :address_long

  def index


  end


end
