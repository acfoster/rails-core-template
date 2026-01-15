class ApplicationController < ActionController::Base
  include ErrorHandling
  include LoggableActions
  include ErrorLogging

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :authenticate_user!, unless: :devise_controller?
  before_action :check_subscription, if: :user_signed_in?, unless: :devise_controller?
  before_action :set_sentry_context, if: :user_signed_in?

  private

  def after_sign_in_path_for(resource_or_scope)
    if resource_or_scope.is_a?(User) && resource_or_scope.admin?
      admin_root_path
    else
      dashboard_path
    end
  end

  def after_sign_out_path_for(resource_or_scope)
    root_path
  end

  def check_subscription
    return if current_user.active_subscription?
    return if controller_name == "subscriptions" || controller_name == "webhooks"

    redirect_to new_subscription_path, alert: "Your trial has expired. Please subscribe to continue."
  end

  def set_sentry_context
    Sentry.set_user(
      id: current_user.id,
      email: current_user.email,
      ip_address: request.remote_ip
    )

    Sentry.set_context("request_info", {
      controller: controller_name,
      action: action_name,
      method: request.method,
      path: request.fullpath,
      request_id: request.uuid
    })
  end
end
