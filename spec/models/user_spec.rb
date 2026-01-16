require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'validations' do
    it { should validate_presence_of(:email) }
  end

  describe 'password strength' do
    it 'rejects short passwords' do
      user = build(:user, password: "Short1!", password_confirmation: "Short1!")
      user.valid?
      expect(user.errors[:password]).to be_present
    end

    it 'rejects long passwords without enough character types' do
      user = build(:user, password: "password1234", password_confirmation: "password1234")
      user.valid?
      expect(user.errors[:password]).to be_present
    end

    it 'accepts mixed-character passwords' do
      user = build(:user, password: "Password123!", password_confirmation: "Password123!")
      expect(user).to be_valid
    end

    it 'accepts long passphrases' do
      passphrase = "this is a long passphrase"
      user = build(:user, password: passphrase, password_confirmation: passphrase)
      expect(user).to be_valid
    end
  end

  describe 'callbacks' do
    let(:user) { build(:user, email: "user_callbacks_#{SecureRandom.hex(4)}@example.com", trial_ends_at: nil) }

    it 'sets trial period after creation' do
      user.save!
      expect(user.trial_ends_at).to be_present
      expect(user.trial_ends_at).to be > Time.current
    end
  end

  describe '#active_subscription?' do
    it 'returns true when status is active' do
      user = build(:user, email: "user_active_#{SecureRandom.hex(4)}@example.com", subscription_status: 'active', trial_ends_at: nil)
      user.save!
      expect(user.active_subscription?).to be true
    end

    it 'returns true when on trial' do
      user = build(:user, email: "user_trial_#{SecureRandom.hex(4)}@example.com", subscription_status: 'trialing', trial_ends_at: nil)
      user.save!
      # Update trial_ends_at after creation to override callback
      user.update_column(:trial_ends_at, 1.day.from_now)
      expect(user.active_subscription?).to be true
    end

    it 'returns false when trial expired' do
      user = build(:user, email: "user_expired_#{SecureRandom.hex(4)}@example.com", subscription_status: 'trialing', trial_ends_at: nil)
      user.save!
      # Update trial_ends_at after creation to set expired date
      user.update_column(:trial_ends_at, 1.day.ago)
      expect(user.active_subscription?).to be false
    end
  end

  describe '#on_trial?' do
    it 'returns true when trialing and trial not expired' do
      user = build(:user, email: "user_on_trial_#{SecureRandom.hex(4)}@example.com", subscription_status: 'trialing', trial_ends_at: nil)
      user.save!
      # Update trial_ends_at after creation
      user.update_column(:trial_ends_at, 1.day.from_now)
      expect(user.on_trial?).to be true
    end

    it 'returns false when trial expired' do
      user = build(:user, email: "user_trial_exp_#{SecureRandom.hex(4)}@example.com", subscription_status: 'trialing', trial_ends_at: nil)
      user.save!
      # Update trial_ends_at after creation to set expired date
      user.update_column(:trial_ends_at, 1.day.ago)
      expect(user.on_trial?).to be false
    end
  end

  describe '#trial_expired?' do
    it 'returns true when trial_ends_at is in the past' do
      user = build(:user, email: "user_trial_expired_#{SecureRandom.hex(4)}@example.com", trial_ends_at: nil)
      user.save!
      user.update_column(:trial_ends_at, 1.day.ago)
      expect(user.trial_expired?).to be true
    end

    it 'returns false when trial_ends_at is in the future' do
      user = build(:user, trial_ends_at: nil)
      user.save!
      user.update_column(:trial_ends_at, 1.day.from_now)
      expect(user.trial_expired?).to be false
    end
  end

end
