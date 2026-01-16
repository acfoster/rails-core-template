class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :confirmable,
         :pwned_password

  enum :role, { user: 0, admin: 1 }

  # Email normalization and validation
  before_validation :normalize_email

  validates :email, length: { maximum: 254 }
  validates :email, format: {
    with: /\A[^\s]+@[^\s]+\.[^\s]+\z/,
    message: "must be a valid email address"
  }
  validate :email_not_disposable

  validates :password, password_strength: true, if: :password_required?

  after_create :set_trial_period

  # Subscription statuses: trialing, active, past_due, canceled, unpaid
  def active_subscription?
    return true if free_access? # Admin granted free access
    subscription_status == "active" || on_trial?
  end

  def on_trial?
    subscription_status == "trialing" && trial_ends_at.present? && trial_ends_at > Time.current
  end

  def trial_expired?
    trial_ends_at.present? && trial_ends_at <= Time.current
  end

  private

  def normalize_email
    self.email = email.to_s.strip.downcase if email.present?
  end

  def email_not_disposable
    return unless email.present?

    domain = email.split('@').last.to_s.downcase
    disposable_domains = Rails.configuration.x.disposable_email_domains || []

    if disposable_domains.include?(domain)
      errors.add(:email, "is from a disposable email provider. Please use a permanent email address.")
    end
  end

  def set_trial_period
    update_column(:trial_ends_at, 5.days.from_now)
  end
end
