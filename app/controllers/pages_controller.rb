class PagesController < ApplicationController

  # rescue_from ActiveRecord::RecordNotFound do |exception|
  #   if exception.message =~ %r{Couldn't find Page/}
  #     raise ActionController::RoutingError, "No such page: #{params[:id]}"
  #   else
  #     raise exception
  #   end
  # end

  # GET /pages
  # GET /pages.json
  def index
    @pages = Page.all

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @pages }
    end
  end

  # GET /pages/1
  # GET /pages/1.json
  def show
    @page = Page.find(params[:id])



    unless @page.template.nil?
      render "pages/templates/#{@page.template}"
    else
      render "show"
    end

  end

  # GET /pages/new
  # GET /pages/new.json
  def new
    @page = Page.new
    @templates = get_page_templates

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @page }
    end
  end

  # GET /pages/1/edit
  def edit
    @templates = get_page_templates
    @page = Page.find(params[:id])
  end

  # POST /pages
  # POST /pages.json
  def create
    @page = Page.new(params[:page])

    respond_to do |format|
      if @page.save
        format.html { redirect_to @page, notice: 'Page was successfully created.' }
        format.json { render json: @page, status: :created, location: @page }
      else
        format.html { render action: "new" }
        format.json { render json: @page.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /pages/1
  # PUT /pages/1.json
  def update
    @page = Page.find(params[:id])

    respond_to do |format|
      if @page.update_attributes(params[:page])
        format.html { redirect_to @page, notice: 'Page was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: "edit" }
        format.json { render json: @page.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /pages/1
  # DELETE /pages/1.json
  def destroy
    @page = Page.find(params[:id])
    @page.destroy

    respond_to do |format|
      format.html { redirect_to pages_url }
      format.json { head :no_content }
    end
  end

private

def get_page_templates
  templates = []
  Dir.foreach("#{Rails.root}/app/views/pages/templates/") do |f|
    unless File.extname(f).empty?
      templates << File.basename(f, ".*")
    end
  end
  templates
end

end
