module Admin
  class BaseController < ApplicationController
    skip_before_action :check_subscription
    before_action :authenticate_user!
    before_action :require_admin

    layout "admin"

    private

    def require_admin
      unless current_user&.admin?
        redirect_to root_path, alert: "Not authorized" and return
      end
    end
  end
end
