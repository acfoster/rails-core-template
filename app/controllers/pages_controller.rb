class PagesController < ApplicationController
  skip_before_action :authenticate_user!
  skip_before_action :check_subscription

  def home
    redirect_to dashboard_path if user_signed_in?
  end

  def terms
  end

  def privacy
  end

  def contact
  end
end
