module Admin
  class UsersController < BaseController
    before_action :set_user, only: [:show, :extend_trial, :toggle_free_access, :toggle_suspension, :set_discount]

    def index
      @users = User.order(created_at: :desc).page(params[:page])
    end

    def show
    end

    def extend_trial
      days = params[:days].to_i
      new_trial_end = if @user.trial_ends_at && @user.trial_ends_at > Time.current
        @user.trial_ends_at + days.days
      else
        days.days.from_now
      end

      @user.update!(trial_ends_at: new_trial_end)
      redirect_to admin_user_path(@user), notice: "Trial extended by #{days} days. New end date: #{new_trial_end.strftime('%B %d, %Y')}"
    end

    def toggle_free_access
      @user.update!(free_access: !@user.free_access?)
      action = @user.free_access? ? "granted" : "removed"
      redirect_to admin_user_path(@user), notice: "Free access #{action} successfully."
    end

    def toggle_suspension
      @user.update!(account_suspended: !@user.account_suspended?)
      action = @user.account_suspended? ? "suspended" : "restored"
      redirect_to admin_user_path(@user), notice: "Account #{action} successfully."
    end

    def set_discount
      percentage = params[:percentage].to_i.clamp(0, 100)
      @user.update!(discount_percentage: percentage)
      redirect_to admin_user_path(@user), notice: "Discount set to #{percentage}%."
    end

    private

    def set_user
      @user = User.find(params[:id])
    end
  end
end
