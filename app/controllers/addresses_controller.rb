require 'rgeo/cartesian/bounding_box'
require "#{Rails.root}/lib/address_helpers.rb"
include AddressHelpers

class AddressesController < ApplicationController
  respond_to :html, :json

  # we are not using  :full => true  because we want to show only street names or addresses. not mix 'em
  autocomplete :address, :address_long

  def index
    @addresses = Address.page(params[:page]).order(:address_long)

    respond_with(@addresses)
  end

  def show
    @city = request.subdomain.split('.').last
    @workflow = params[:workflow]
    puts "city => #{@city}"
    puts "workflow => #{@workflow}"
   
    if user_signed_in?
      @user = current_user
      @user_subscribed = !@user.subscriptions.where(:address_id => params[:id]).empty?
    end
    puts "Request:"
    puts request.subdomain.inspect
    @address = Address.find(params[:id])
    @address.load_open_cases#(city,workflow)

    # if APP_CONFIG['demo_page_id'] == @address.id
    #   render :action => 'show-demo'
    # else
      #respond_with(@address, @user_subscribed)
    # end
    respond_to do |format|
        format.html
        format.json { render :json => {:address => @address, :user => @user}}
      end
  end


  def search
    RGeo::ActiveRecord::GeometryMixin.set_json_generator(:geojson)

    @search_term = search_term = params[:address]
    Search.create(:term => search_term, :ip => request.remote_ip)

    address_result = AddressHelpers.find_address(params[:address])

    # When user searches they get a direct hit!
    if address_result.length == 1
      redirect_to :action => "show", :id => address_result.first.id
    else
      neighborhood = search_term.to_s.upcase
      if Neighborhood.exists?(:name => neighborhood)
        addresses = Address.find_addresses_with_cases_by_neighborhood(neighborhood)
      else
        street_name = AddressHelpers.get_street_name(search_term)

        if(dir = AddressHelpers.get_direction(search_term))
          addresses = Address.find_addresses_with_cases_by_cardinal_street(dir,street_name).uniq.order(:house_num)
        else
          addresses = Address.find_addresses_with_cases_by_street(street_name).uniq.order(:street_name, :house_num)
        end
      end

      addresses.each {|addr|
        addr.address_long = AddressHelpers.unabbreviate_street_types(addr.address_long).capitalize
      }

      @addresses = addresses.sort{ |a, b| a.house_num.to_i <=> b.house_num.to_i }

      @results_empty = @addresses.empty?
      respond_to do |format|
        format.html
        format.json { render :json => @addresses.to_json(:only => [ :id, :address_long, :latest_type, :point ]) }
      end
    end
  end


  def addresses_with_case
    RGeo::ActiveRecord::GeometryMixin.set_json_generator(:geojson)
    date = Time.now

    params[:start_date] = params[:start_date].nil? ? (date - 1.month).to_s : params[:start_date]

    start = Date.parse(params[:start_date])

    start_date = start.strftime('%Y-%m-%d')
    end_date = start + 1.month - 1.day
    class_name = ''

    append_sql_query = ''
    sql_params = {:start_date => start_date, :end_date => end_date}

    if params[:only_recent_status].to_i == 1
      append_sql_query = " AND cases.status_type = :status_type "
      case params[:status]
        when 'inspections'
          sql_params[:status_type] = "Inspection"
        when 'notifications'
          sql_params[:status_type] = "Notification"
        when 'hearings'
          sql_params[:status_type] = "Hearing"
        when 'judgement'
          sql_params[:status_type] = "Judgement"
        when 'foreclosures'
          sql_params[:status_type] = "Foreclosure"
        when 'demolitions'
          sql_params[:status_type] = "Demolition"
        # when 'abatement'
        #   sql_params[:status_type] = "Maintenance"
      end
    end

    append_sql_query = " #{append_sql_query} AND cases.state = :state "

    if params[:case_open].to_i == 1
      sql_params[:state] = "Open"
    else
      sql_params[:state] = "Closed"
    end


    case params[:status]
      when 'inspections'
        cases = Case.includes(:address, :events).where(" events.step = 'Inspection' AND cases.address_id = addresses.id  AND events.date > :start_date AND events.date < :end_date #{append_sql_query} ",  sql_params)
        # cases = Case.includes(:address, :inspections).where(" cases.address_id = addresses.id  AND inspections.inspection_date > :start_date AND inspections.inspection_date < :end_date #{append_sql_query} ",  sql_params)
      when 'notifications'
        cases = Case.includes(:address, :events).where(" events.step = 'Notification' AND cases.address_id = addresses.id  AND events.date > :start_date  AND events.date < :end_date #{append_sql_query}",   sql_params)
      when 'hearings'
        cases = Case.includes(:address, :events).where(" events.step = 'Hearing' AND cases.address_id = addresses.id  AND  events.date > :start_date  AND events.date < :end_date #{append_sql_query}",   sql_params )
      when 'judgment'
        cases = Case.includes(:address, :events).where(" events.step = 'Judgment' AND cases.address_id = addresses.id  AND  events.date > :start_date  AND events.date < :end_date #{append_sql_query}", sql_params )
      when "resolution"
        cases = Case.includes(:address,:events).where(" event.step = 'Resolution' AND cases.address_id = address.id AND events.date > :start_date  AND foreclosures.sale_date <  :end_date  " ,  sql_params )
    end


    # TODO: REWRITE FRONTEND SO IT CAN HANDLE RETURNED ARRAY OF ADDRESSES
    if params[:status] == 'inspections' || params[:status] == 'notifications' || params[:status] == 'hearings'|| params[:status] == 'judgment'
      if cases.nil?
        cases = {}
      end
      case_addresses = cases.map{| single_case |
        single = {}
        single = single_case.address
        single[:status_type] = single_case.status_type
        single
      }
    end

    respond_to do |format|
        format.json { render :json => case_addresses.to_json(:only => [ :id, :address_long, :latest_type, :status_type, :point ]) }
    end
  end



  def map_search
    ne = params["northEast"]
    sw = params["southWest"]
    @addresses = Address.find_addresses_with_cases_within_area(ne, sw)

    # respond_with [@addresses.to_json(:methods => [:most_recent_status_preview])]

    respond_to do |format|
        format.json { render :json => @addresses.to_json }
    end
  end


  def redirect_latlong
    # factory = RGeo::Cartesian.factory
    # location = factory.point(params[:x].to_f, params[:y].to_f)
    @address = Address.where(" point = ST_GeomFromText('POINT(#{params[:x].to_f} #{params[:y].to_f})') " ).first
    redirect_to address_url(@address), :status => :found
  end


  private

  # DEPRCATED
  def get_stats(status, sql_params)
    Rails.logger.debug '-----------GET STATS-----------------'
    Rails.logger.debug status.inspect
    Rails.logger.debug sql_params.inspect
    Event.where("step = '#{status.singularize.capitalize}' AND date > :start_date AND date < :end_date ",  sql_params).results
  end

end
