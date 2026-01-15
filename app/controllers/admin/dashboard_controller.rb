module Admin
  class DashboardController < BaseController
    def index
      @total_users = User.count
      @active_subscriptions = User.where(subscription_status: "active").count
      @trialing_users = User.where(subscription_status: "trialing").count
      @free_access_users = User.where(free_access: true).count
      @suspended_users = User.where(account_suspended: true).count
      @trial_expired = User.where("trial_ends_at < ?", Time.current).where(subscription_status: "trialing").count

      # Conversion metrics
      @trial_to_paid_conversion = calculate_trial_to_paid_conversion

      @recent_users = User.order(created_at: :desc).limit(10)
    end

    private

    def calculate_trial_to_paid_conversion
      total_completed_trials = User.where("trial_ends_at < ?", Time.current).count
      return 0 if total_completed_trials.zero?

      converted = User.where(subscription_status: "active").where("trial_ends_at < ?", Time.current).count
      ((converted.to_f / total_completed_trials) * 100).round(1)
    end
  end
end
