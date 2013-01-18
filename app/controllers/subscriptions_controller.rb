class SubscriptionsController < ApplicationController
  respond_to :html, :json
  # before_filter :authenticate_user!

  def update
    user = current_user
    # points = Array.new
    # factory = RGeo::Cartesian.factory

    # params[:polygon].each{|index, item|
    #   puts item.inspect
    #   points.push(factory.point( item['lng'].to_f, item['lat'].to_f ))
    # }

    # polygon = factory.polygon(factory.linear_ring(points))

    @subscription = Subscription.find_or_create_by_address_id_and_user_id({:address_id => params[:id], :user_id => user.id, :date_notified => Time.now })


    if @subscription.save
      respond_to do |format|
        format.html
        format.json { render :json => @subscription.to_json }
      end
    end
  end


  def destroy
    user = current_user

    @subscription = Subscription.destroy_all({:address_id => params[:id], :user_id => user.id})

    if @subscription
      respond_to do |format|
        format.html
        format.json { render :json => @subscription.to_json }
      end
    end
  end

end
