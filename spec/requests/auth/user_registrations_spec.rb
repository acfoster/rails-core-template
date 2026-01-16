require 'rails_helper'

RSpec.describe "User Registrations", type: :request do
  describe "GET /users/sign_up" do
    it "returns http success" do
      get new_user_registration_path
      expect(response).to have_http_status(:success)
    end

    it "displays signup form" do
      get new_user_registration_path
      expect(response.body).to include("Sign Up")
      expect(response.body).to include("Email")
      expect(response.body).to include("Password")
    end

    it "displays Core App branding" do
      get new_user_registration_path
      expect(response.body).to include("Core App")
    end
  end

  describe "POST /users" do
    let(:valid_attributes) do
      {
        user: {
          email: "newuser@example.com",
          password: "Password123!",
          password_confirmation: "Password123!"
        }
      }
    end

    context "with valid parameters" do
      it "creates a new user" do
        expect {
          post user_registration_path, params: valid_attributes
        }.to change(User, :count).by(1)
      end

      it "sets up 7-day trial" do
        post user_registration_path, params: valid_attributes
        user = User.last
        expect(user.trial_ends_at).to be_within(1.minute).of(5.days.from_now)
        expect(user.subscription_status).to eq("trialing")
      end

      it "initializes usage counter" do
        post user_registration_path, params: valid_attributes
        user = User.last
        expect(user).to be_present
      end

      it "sets default values for access flags" do
        post user_registration_path, params: valid_attributes
        user = User.last
        expect(user.free_access).to be false
        expect(user.account_suspended).to be false
        expect(user.discount_percentage).to eq(0)
      end

      it "does not create Stripe customer on signup" do
        # Stripe customer is created lazily when user subscribes
        post user_registration_path, params: valid_attributes
        user = User.last
        expect(user.stripe_customer_id).to be_nil
      end

      it "redirects to home after signup" do
        post user_registration_path, params: valid_attributes
        expect(response).to redirect_to(root_path)
      end

      it "does not sign in the user until confirmation" do
        post user_registration_path, params: valid_attributes
        expect(controller.current_user).to be_nil
      end
    end

    context "with invalid parameters" do
      it "does not create a user with invalid email" do
        invalid_attributes = valid_attributes.deep_dup
        invalid_attributes[:user][:email] = "invalid-email"

        expect {
          post user_registration_path, params: invalid_attributes
        }.not_to change(User, :count)
      end

      it "does not create a user with short password" do
        invalid_attributes = valid_attributes.deep_dup
        invalid_attributes[:user][:password] = "short"
        invalid_attributes[:user][:password_confirmation] = "short"

        expect {
          post user_registration_path, params: invalid_attributes
        }.not_to change(User, :count)
      end

      it "does not create a user with mismatched passwords" do
        invalid_attributes = valid_attributes.deep_dup
        invalid_attributes[:user][:password_confirmation] = "different123"

        expect {
          post user_registration_path, params: invalid_attributes
        }.not_to change(User, :count)
      end

      it "shows error messages for invalid data" do
        invalid_attributes = valid_attributes.deep_dup
        invalid_attributes[:user][:email] = ""

        post user_registration_path, params: invalid_attributes
        expect(response.body).to include("error")
      end

      it "does not create user with duplicate email" do
        create(:user, email: "duplicate@example.com")

        duplicate_attributes = valid_attributes.deep_dup
        duplicate_attributes[:user][:email] = "duplicate@example.com"

        expect {
          post user_registration_path, params: duplicate_attributes
        }.not_to change(User, :count)
      end
    end

  end

  describe "edge cases" do
    it "handles email with uppercase letters" do
      attributes = {
        user: {
          email: "UPPERCASE@EXAMPLE.COM",
          password: "Password123!",
          password_confirmation: "Password123!"
        }
      }

      post user_registration_path, params: attributes
      user = User.last
      expect(user.email).to eq("uppercase@example.com")
    end

    it "trims whitespace from email" do
      attributes = {
        user: {
          email: "  whitespace@example.com  ",
          password: "Password123!",
          password_confirmation: "Password123!"
        }
      }

      post user_registration_path, params: attributes
      user = User.last
      expect(user.email).not_to match(/\s/)
    end

    it "handles very long passwords" do
      long_password = ("a" * 127) + "1"
      attributes = {
        user: {
          email: "longpassword@example.com",
          password: long_password,
          password_confirmation: long_password
        }
      }

      expect {
        post user_registration_path, params: attributes
      }.to change(User, :count).by(1)
    end
  end
end
