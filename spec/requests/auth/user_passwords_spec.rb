require 'rails_helper'

RSpec.describe "User Passwords", type: :request do
  let!(:user) { create(:user, password: "oldpassword123", password_confirmation: "oldpassword123") }

  describe "GET /users/password/new" do
    it "returns http success" do
      get new_user_password_path
      expect(response).to have_http_status(:success)
    end

    it "displays forgot password form" do
      get new_user_password_path
      expect(response.body).to include("Forgot Password?")
      expect(response.body).to include("Email")
    end

    it "displays Core App branding" do
      get new_user_password_path
      expect(response.body).to include("Core App")
    end

    it "displays link back to login" do
      get new_user_password_path
      expect(response.body).to include("Log in")
    end
  end

  describe "POST /users/password" do
    before do
      ActionMailer::Base.deliveries.clear
    end
    context "with valid email" do
      it "sends password reset email" do
        expect {
          post user_password_path, params: {
            user: {
              email: user.email
            }
          }
        }.to change { ActionMailer::Base.deliveries.count }.by(1)
      end

      it "generates reset password token" do
        post user_password_path, params: {
          user: {
            email: user.email
          }
        }
        user.reload
        expect(user.reset_password_token).to be_present
      end

      it "sets reset password sent at timestamp" do
        travel_to Time.current do
          post user_password_path, params: {
            user: {
              email: user.email
            }
          }
          user.reload
          expect(user.reset_password_sent_at).to be_within(1.second).of(Time.current)
        end
      end

      it "redirects to login page" do
        post user_password_path, params: {
          user: {
            email: user.email
            }
        }
        expect(response).to redirect_to(new_user_session_path)
      end

      it "shows success message" do
        post user_password_path, params: {
          user: {
            email: user.email
          }
        }
        follow_redirect!
        expect(response.body).to include("You will receive an email")
      end

      it "sends email with reset link" do
        post user_password_path, params: {
          user: {
            email: user.email
          }
        }
        mail = ActionMailer::Base.deliveries.last
        expect(mail.to).to eq([user.email])
        expect(mail.subject).to include("password")
        expect(mail.body.encoded).to include("reset_password_token")
      end
    end

    context "with invalid email" do
      it "does not send email for non-existent user" do
        expect {
          post user_password_path, params: {
            user: {
              email: "nonexistent@example.com"
            }
          }
        }.not_to change { ActionMailer::Base.deliveries.count }
      end

      it "shows error for blank email" do
        post user_password_path, params: {
          user: {
            email: ""
          }
        }
        expect(response.body).to include("Email can&#39;t be blank")
      end

      it "shows error for invalid email format" do
        post user_password_path, params: {
          user: {
            email: "invalid-email"
          }
        }
        expect(response.body).to include("error")
      end
    end

    context "multiple reset requests" do
      it "invalidates old token when new one is requested" do
        # First request
        post user_password_path, params: { user: { email: user.email } }
        user.reload
        old_token = user.reset_password_token

        # Second request
        post user_password_path, params: { user: { email: user.email } }
        user.reload
        new_token = user.reset_password_token

        expect(new_token).not_to eq(old_token)
      end

      it "sends multiple emails if requested multiple times" do
        expect {
          3.times do
            post user_password_path, params: { user: { email: user.email } }
          end
        }.to change { ActionMailer::Base.deliveries.count }.by(3)
      end
    end
  end

  describe "GET /users/password/edit" do
    let(:reset_token) { user.send_reset_password_instructions }

    it "returns http success with valid token" do
      get edit_user_password_path, params: { reset_password_token: reset_token }
      expect(response).to have_http_status(:success)
    end

    it "displays password reset form" do
      get edit_user_password_path, params: { reset_password_token: reset_token }
      expect(response.body).to include("Reset Password")
      expect(response.body).to include("New Password")
      expect(response.body).to include("Confirm New Password")
    end

    it "renders form with invalid token" do
      get edit_user_password_path, params: { reset_password_token: "invalid_token" }
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Reset Password")
    end

    it "renders form with expired token" do
      user.send_reset_password_instructions
      user.update!(reset_password_sent_at: 7.hours.ago)

      get edit_user_password_path, params: { reset_password_token: user.reset_password_token }
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Reset Password")
    end
  end

  describe "PUT /users/password" do
    let(:reset_token) { user.send_reset_password_instructions }

    context "with valid parameters" do
      let(:valid_params) do
        {
          user: {
            reset_password_token: reset_token,
            password: "newpassword123",
            password_confirmation: "newpassword123"
          }
        }
      end

      it "changes the password" do
        put user_password_path, params: valid_params
        user.reload
        expect(user.valid_password?("newpassword123")).to be true
        expect(user.valid_password?("oldpassword123")).to be false
      end

      it "clears the reset password token" do
        put user_password_path, params: valid_params
        user.reload
        expect(user.reset_password_token).to be_nil
      end

      it "clears the reset password sent at timestamp" do
        put user_password_path, params: valid_params
        user.reload
        expect(user.reset_password_sent_at).to be_nil
      end

      it "signs in the user automatically" do
        put user_password_path, params: valid_params
        expect(controller.current_user).to eq(user)
      end

      it "redirects to dashboard" do
        put user_password_path, params: valid_params
        expect(response).to redirect_to(dashboard_path)
      end

      it "shows success message" do
        put user_password_path, params: valid_params
        expect(flash[:notice]).to be_present
      end
    end

    context "with invalid parameters" do
      it "does not change password with mismatched confirmation" do
        put user_password_path, params: {
          user: {
            reset_password_token: reset_token,
            password: "newpassword123",
            password_confirmation: "different123"
          }
        }
        user.reload
        expect(user.valid_password?("oldpassword123")).to be true
      end

      it "does not change password with too short password" do
        put user_password_path, params: {
          user: {
            reset_password_token: reset_token,
            password: "short",
            password_confirmation: "short"
          }
        }
        user.reload
        expect(user.valid_password?("oldpassword123")).to be true
      end

      it "shows error for blank password" do
        put user_password_path, params: {
          user: {
            reset_password_token: reset_token,
            password: "",
            password_confirmation: ""
          }
        }
        expect(response.body).to include("Password can&#39;t be blank")
      end

      it "does not change password with invalid token" do
        put user_password_path, params: {
          user: {
            reset_password_token: "invalid_token",
            password: "newpassword123",
            password_confirmation: "newpassword123"
          }
        }
        user.reload
        expect(user.valid_password?("oldpassword123")).to be true
      end

      it "does not change password with expired token" do
        # Generate token, then manually expire it
        token = user.send_reset_password_instructions

        # Travel to 7 hours in the future to expire the token
        travel 7.hours do
          put user_password_path, params: {
            user: {
              reset_password_token: token,
              password: "newpassword123",
              password_confirmation: "newpassword123"
            }
          }
          user.reload
          expect(user.valid_password?("oldpassword123")).to be true
        end
      end
    end

    context "token security" do
      it "cannot use token twice" do
        valid_params = {
          user: {
            reset_password_token: reset_token,
            password: "newpassword123",
            password_confirmation: "newpassword123"
          }
        }

        # First use - should work
        put user_password_path, params: valid_params
        expect(response).to redirect_to(dashboard_path)

        # Sign out
        delete destroy_user_session_path

        # Second use - should fail with unprocessable content
        put user_password_path, params: valid_params
        user.reload
        expect(user.valid_password?("newpassword123")).to be true
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "token expires after 6 hours" do
        user.send_reset_password_instructions
        user.update!(reset_password_sent_at: 7.hours.ago)

        put user_password_path, params: {
          user: {
            reset_password_token: user.reset_password_token,
            password: "newpassword123",
            password_confirmation: "newpassword123"
          }
        }

        user.reload
        expect(user.valid_password?("oldpassword123")).to be true
      end
    end
  end

  describe "edge cases" do
    it "handles email with different case" do
      user = create(:user, email: "edgecase@example.com", password: "oldpassword123", password_confirmation: "oldpassword123")
      expect {
        post user_password_path, params: {
          user: {
            email: "EDGECASE@EXAMPLE.COM"
          }
        }
      }.to change { ActionMailer::Base.deliveries.count }.by(1)
    end

    it "handles email with whitespace" do
      user = create(:user, email: "whitespace2@example.com", password: "oldpassword123", password_confirmation: "oldpassword123")
      expect {
        post user_password_path, params: {
          user: {
            email: "  whitespace2@example.com  "
          }
        }
      }.to change { ActionMailer::Base.deliveries.count }.by(1)
    end

    it "handles very long passwords on reset" do
      reset_token = user.send_reset_password_instructions
      long_password = ("a" * 127) + "1"

      put user_password_path, params: {
        user: {
          reset_password_token: reset_token,
          password: long_password,
          password_confirmation: long_password
        }
      }

      user.reload
      expect(user.valid_password?(long_password)).to be true
    end

    it "preserves user data after password reset" do
      original_email = user.email
      original_trial = user.trial_ends_at

      reset_token = user.send_reset_password_instructions

      put user_password_path, params: {
        user: {
          reset_password_token: reset_token,
          password: "newpassword123",
          password_confirmation: "newpassword123"
        }
      }

      user.reload
      expect(user.email).to eq(original_email)
      expect(user.trial_ends_at).to eq(original_trial)
      expect(user).to be_present
    end
  end
end
