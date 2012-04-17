class CasesController < ApplicationController
  respond_to :html, :json, :xml

  def index
    @cases = Case.page(params[:page])
    respond_with(@cases)
  end

  def show
    @case = Case.find(params[:id])
    respond_with(@case)
  end
end
