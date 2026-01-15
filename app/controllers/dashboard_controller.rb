class DashboardController < ApplicationController
  def index
  end

  def poll
    render json: { status: "ok" }
  end
end
