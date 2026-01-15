require 'rails_helper'

RSpec.describe "User Sessions", type: :request do
  let(:user) { create(:user, password: "password123", password_confirmation: "password123") }

  describe "GET /users/sign_in" do
    it "returns http success" do
      get new_user_session_path
      expect(response).to have_http_status(:success)
    end

    it "displays login form" do
      get new_user_session_path
      expect(response.body).to include("Sign In")
      expect(response.body).to include("Email")
      expect(response.body).to include("Password")
    end

    it "displays Core App branding" do
      get new_user_session_path
      expect(response.body).to include("Core App")
    end

    it "displays link to sign up" do
      get new_user_session_path
      expect(response.body).to include("Sign Up")
    end

    it "displays forgot password link" do
      get new_user_session_path
      expect(response.body).to include("Forgot your password")
    end

    context "when already logged in" do
      before do
        sign_in user
      end

      it "redirects to dashboard" do
        get new_user_session_path
        expect(response).to redirect_to(dashboard_path)
      end
    end
  end

  describe "POST /users/sign_in" do
    context "with valid credentials" do
      let(:valid_params) do
        {
          user: {
            email: user.email,
            password: "password123"
          }
        }
      end

      it "signs in the user" do
        post user_session_path, params: valid_params
        expect(controller.current_user).to eq(user)
      end

      it "redirects to dashboard" do
        post user_session_path, params: valid_params
        expect(response).to redirect_to(dashboard_path)
      end

      it "sets a flash notice" do
        post user_session_path, params: valid_params
        expect(flash[:notice]).to be_present
      end

      it "creates a session" do
        post user_session_path, params: valid_params
        expect(controller.current_user).to eq(user)
      end
    end

    context "with invalid credentials" do
      it "does not sign in with wrong password" do
        post user_session_path, params: {
          user: {
            email: user.email,
            password: "wrongpassword"
          }
        }
        expect(controller.current_user).to be_nil
      end

      it "does not sign in with wrong email" do
        post user_session_path, params: {
          user: {
            email: "wrong@example.com",
            password: "password123"
          }
        }
        expect(controller.current_user).to be_nil
      end

      it "shows error message for invalid credentials" do
        post user_session_path, params: {
          user: {
            email: user.email,
            password: "wrongpassword"
          }
        }
        expect(flash[:alert]).to be_present
      end

      it "renders login form again" do
        post user_session_path, params: {
          user: {
            email: user.email,
            password: "wrongpassword"
          }
        }
        expect(response.body).to include("Sign In")
      end

      it "does not sign in with empty email" do
        post user_session_path, params: {
          user: {
            email: "",
            password: "password123"
          }
        }
        expect(controller.current_user).to be_nil
      end

      it "does not sign in with empty password" do
        post user_session_path, params: {
          user: {
            email: user.email,
            password: ""
          }
        }
        expect(controller.current_user).to be_nil
      end
    end

    context "with suspended account" do
      before do
        user.update!(account_suspended: true)
      end

      it "allows login for suspended accounts" do
        post user_session_path, params: {
          user: {
            email: user.email,
            password: "password123"
          }
        }
        # Login succeeds
        expect(controller.current_user).to eq(user)
        expect(user.account_suspended).to be true
      end
    end

    context "with expired trial" do
      before do
        user.update!(trial_ends_at: 1.day.ago, subscription_status: 'trialing')
      end

      it "allows login" do
        post user_session_path, params: {
          user: {
            email: user.email,
            password: "password123"
          }
        }
        expect(controller.current_user).to eq(user)
      end

      it "redirects to subscription page when trying to access protected pages" do
        sign_in user
        get dashboard_path
        expect(response).to redirect_to(new_subscription_path)
      end
    end

    context "remember me functionality" do
      it "remembers user when remember_me is checked" do
        post user_session_path, params: {
          user: {
            email: user.email,
            password: "password123",
            remember_me: "1"
          }
        }
        expect(response.cookies['remember_user_token']).to be_present
      end

      it "does not remember user when remember_me is unchecked" do
        post user_session_path, params: {
          user: {
            email: user.email,
            password: "password123",
            remember_me: "0"
          }
        }
        expect(response.cookies['remember_user_token']).to be_nil
      end
    end
  end

  describe "DELETE /users/sign_out" do
    before do
      sign_in user
    end

    it "signs out the user" do
      delete destroy_user_session_path
      expect(controller.current_user).to be_nil
    end

    it "redirects to root path" do
      delete destroy_user_session_path
      expect(response).to redirect_to(root_path)
    end

    it "clears the session" do
      delete destroy_user_session_path
      expect(session[:warden_session_serializer]).to be_nil
    end

    it "shows signed out message" do
      delete destroy_user_session_path
      expect(flash[:notice]).to be_present
    end

    it "prevents access to protected pages after logout" do
      delete destroy_user_session_path
      get dashboard_path
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe "protected routes" do
    context "when not logged in" do
      it "redirects dashboard to login" do
        get dashboard_path
        expect(response).to redirect_to(new_user_session_path)
      end

      it "sets flash alert message" do
        get dashboard_path
        expect(flash[:alert]).to be_present
      end
    end

    context "when logged in" do
      before do
        sign_in user
      end

      it "allows access to dashboard" do
        get dashboard_path
        expect(response).to have_http_status(:success)
      end
    end
  end

  describe "edge cases" do
    it "handles case-insensitive email login" do
      user = create(:user, email: "casetest@example.com", password: "password123", password_confirmation: "password123")
      post user_session_path, params: {
        user: {
          email: "CASETEST@EXAMPLE.COM",
          password: "password123"
        }
      }
      expect(controller.current_user).to eq(user)
    end

    it "handles email with extra whitespace" do
      user = create(:user, email: "whitespace@example.com", password: "password123", password_confirmation: "password123")
      post user_session_path, params: {
        user: {
          email: "  whitespace@example.com  ",
          password: "password123"
        }
      }
      expect(controller.current_user).to eq(user)
    end

    it "prevents timing attacks by taking same time for invalid emails" do
      time_valid = Benchmark.realtime do
        post user_session_path, params: {
          user: {
            email: user.email,
            password: "wrongpassword"
          }
        }
      end

      time_invalid = Benchmark.realtime do
        post user_session_path, params: {
          user: {
            email: "nonexistent@example.com",
            password: "wrongpassword"
          }
        }
      end

      # Times should be similar (within 0.5 seconds)
      expect((time_valid - time_invalid).abs).to be < 0.5
    end
  end
end
