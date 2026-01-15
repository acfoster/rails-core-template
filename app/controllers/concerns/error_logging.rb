module ErrorLogging
  extend ActiveSupport::Concern

  included do
    rescue_from StandardError, with: :log_and_handle_error
  end

  private

  def log_and_handle_error(exception)
    Log.log(
      log_type: 'error',
      level: 'error',
      message: "Unhandled exception: #{exception.message}",
      user: current_user,
      action: 'unhandled_exception',
      controller: controller_name,
      request_id: request.request_id,
      ip_address: request.remote_ip,
      context: {
        exception_class: exception.class.name,
        exception_message: exception.message,
        backtrace: exception.backtrace&.first(10),
        request_method: request.method,
        request_path: request.path,
        params: params.except(:authenticity_token, :password, :password_confirmation).to_unsafe_h
      }
    )

    # Re-raise to let Rails handle it normally
    raise exception
  end
end
