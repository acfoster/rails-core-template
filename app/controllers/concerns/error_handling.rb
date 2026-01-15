module ErrorHandling
  extend ActiveSupport::Concern

  included do
    rescue_from StandardError, with: :handle_standard_error
    rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found
    rescue_from ActiveRecord::RecordInvalid, with: :handle_invalid_record
    rescue_from ActionController::ParameterMissing, with: :handle_parameter_missing
  end

  private

  def handle_standard_error(exception)
    log_controller_error(exception, severity: :error)

    respond_to do |format|
      format.html do
        flash[:alert] = "An unexpected error occurred. Our team has been notified."
        redirect_back fallback_location: root_path
      end
      format.json { render json: { error: "Internal server error" }, status: :internal_server_error }
    end
  end

  def handle_not_found(exception)
    log_controller_error(exception, severity: :warn)

    respond_to do |format|
      format.html do
        flash[:alert] = "The requested resource was not found."
        redirect_to root_path
      end
      format.json { render json: { error: "Not found" }, status: :not_found }
    end
  end

  def handle_invalid_record(exception)
    log_controller_error(exception, severity: :warn)

    respond_to do |format|
      format.html do
        flash[:alert] = "Validation failed: #{exception.record.errors.full_messages.join(', ')}"
        redirect_back fallback_location: root_path
      end
      format.json do
        render json: {
          error: "Validation failed",
          details: exception.record.errors.full_messages
        }, status: 422
      end
    end
  end

  def handle_parameter_missing(exception)
    log_controller_error(exception, severity: :warn)

    respond_to do |format|
      format.html do
        flash[:alert] = "Required parameter missing: #{exception.param}"
        redirect_back fallback_location: root_path
      end
      format.json do
        render json: {
          error: "Parameter missing",
          parameter: exception.param
        }, status: :bad_request
      end
    end
  end

  def log_controller_error(exception, severity: :error)
    ApplicationLogger.log_error(
      exception,
      context: build_error_context,
      user: current_user,
      component: controller_component_name,
      severity: severity
    )
  end

  def build_error_context
    {
      controller: controller_name,
      action: action_name,
      method: request.method,
      path: request.fullpath,
      params: sanitized_params,
      referer: request.referer,
      user_agent: request.user_agent,
      ip_address: request.remote_ip,
      request_id: request.uuid
    }
  end

  def sanitized_params
    # Remove sensitive data from params
    params.except(:password, :password_confirmation, :current_password, :authenticity_token).to_unsafe_h
  end

  def controller_component_name
    "controller_#{controller_name}"
  end

  # Helper to log successful user actions
  def log_user_action(action, details = {})
    return unless current_user

    ApplicationLogger.log_user_action(
      action: action,
      user: current_user,
      details: details.merge(
        controller: controller_name,
        action_name: action_name
      )
    )
  end
end
