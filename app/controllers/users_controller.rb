class UsersController < ApplicationController
  before_filter :authenticate_user!
  respond_to :html, :json

  def index
    @user = current_user
    @user_subcriptions = @user.addresses

    respond_to do |format|
      format.html
      format.json { render :json => @user_subcriptions.to_json }
    end
  end

  def map
    @user = current_user
    @polygon_subcriptions = Subscription.where(:user_id => @user.id)

    polygon = Subscription.last.thegeom
    geojson = RGeo::GeoJSON::encode(polygon)

    respond_to do |format|
      format.html
      format.json { render :json => geojson.to_json }
    end
  end

  def notify
    @user = current_user
    if @user.update_attributes(params[:user])
      render :json => {:saved => true}
    else
      render :json => {:saved => false}
    end
  end

  def show

  end

  def edit
  end
end