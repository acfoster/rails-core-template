require 'rails_helper'

RSpec.describe 'User login', type: :request do
  let(:user) { FactoryBot.create(:user, password: 'password123', password_confirmation: 'password123') }

  it 'logs in with valid credentials and sets session' do
    post user_session_path, params: { user: { email: user.email, password: 'password123' } }
    expect(response).to redirect_to(dashboard_path)
    expect(controller.current_user).to eq(user)
  end

  it 'does not log in with invalid credentials' do
    post user_session_path, params: { user: { email: user.email, password: 'wrongpass' } }
    expect(response.body).to include('Invalid Email or password')
  end
end

# Admin login tests are skipped until Admin model/factory is implemented
