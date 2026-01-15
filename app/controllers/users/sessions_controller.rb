class Users::SessionsController < Devise::SessionsController
  def create
    email = params[:user][:email]

    Rails.logger.info "User login attempt: #{email}"
    Log.log(
      log_type: 'authentication',
      level: 'info',
      message: "Login attempt",
      action: 'login_attempt',
      controller: 'users/sessions',
      request_id: request.request_id,
      ip_address: request.remote_ip,
      context: { email: email }
    )

    super do |user|
      if user.persisted?
        Rails.logger.info "User logged in successfully: #{user.email} (ID: #{user.id})"
        Log.log(
          log_type: 'authentication',
          level: 'info',
          message: "User logged in successfully",
          user: user,
          action: 'login_success',
          controller: 'users/sessions',
          request_id: request.request_id,
          ip_address: request.remote_ip,
          context: { email: user.email }
        )
      else
        Rails.logger.warn "Failed login attempt for: #{email}"
        Log.log(
          log_type: 'authentication',
          level: 'warning',
          message: "Failed login attempt - invalid credentials",
          action: 'login_failure',
          controller: 'users/sessions',
          request_id: request.request_id,
          ip_address: request.remote_ip,
          context: { email: email }
        )
      end
    end
  end

  def destroy
    user_email = current_user&.email
    user_id = current_user&.id

    Rails.logger.info "User logged out: #{user_email} (ID: #{user_id})"
    Log.log(
      log_type: 'authentication',
      level: 'info',
      message: "User logged out",
      user: current_user,
      action: 'logout',
      controller: 'users/sessions',
      request_id: request.request_id,
      ip_address: request.remote_ip,
      context: { email: user_email }
    )

    super
  end
end
