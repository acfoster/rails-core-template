class Users::RegistrationsController < Devise::RegistrationsController
  def create
    Rails.logger.info "New user registration attempt: #{params[:user][:email]}"
    Log.log(
      log_type: 'authentication',
      level: 'info',
      message: "Registration attempt",
      action: 'registration_attempt',
      controller: 'users/registrations',
      request_id: request.request_id,
      ip_address: request.remote_ip,
      context: { email: params[:user][:email] }
    )

    super do |user|
      if user.persisted?
        Rails.logger.info "User registered successfully: #{user.email} (ID: #{user.id})"
        Log.log(
          log_type: 'authentication',
          level: 'info',
          message: "User registered successfully",
          user: user,
          action: 'registration_success',
          controller: 'users/registrations',
          request_id: request.request_id,
          ip_address: request.remote_ip,
          context: { email: user.email, trial_ends_at: user.trial_ends_at }
        )
      else
        Rails.logger.warn "Failed registration for: #{params[:user][:email]} - #{user.errors.full_messages.join(', ')}"
        Log.log(
          log_type: 'authentication',
          level: 'warning',
          message: "Failed registration: #{user.errors.full_messages.join(', ')}",
          action: 'registration_failure',
          controller: 'users/registrations',
          request_id: request.request_id,
          ip_address: request.remote_ip,
          context: { email: params[:user][:email], errors: user.errors.full_messages }
        )
      end
    end
  end

  def update
    self.resource = resource_class.to_adapter.get!(send(:"current_#{resource_name}").to_key)

    Rails.logger.info "User account update attempt: #{current_user.email} (ID: #{current_user.id})"

    resource_updated = update_resource(resource, account_update_params)

    if resource_updated
      Log.log(
        log_type: 'user_action',
        level: 'info',
        message: "Account updated successfully",
        user: current_user,
        action: 'account_update',
        controller: 'users/registrations',
        request_id: request.request_id,
        ip_address: request.remote_ip
      )

      bypass_sign_in resource, scope: resource_name if sign_in_after_change_password?
      redirect_to profile_account_path, notice: "Your account has been updated successfully."
    else
      Log.log(
        log_type: 'user_action',
        level: 'warning',
        message: "Failed account update: #{resource.errors.full_messages.join(', ')}",
        user: current_user,
        action: 'account_update_failure',
        controller: 'users/registrations',
        request_id: request.request_id,
        ip_address: request.remote_ip,
        context: { errors: resource.errors.full_messages }
      )

      clean_up_passwords resource
      # Store errors in flash so account page can display them
      flash.now[:alert] = resource.errors.full_messages.join(", ")
      @user = resource
      render "users/account", status: 422
    end
  end
end
