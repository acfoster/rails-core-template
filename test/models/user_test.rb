require 'test_helper'

class UserTest < ActiveSupport::TestCase
  # Email normalization tests
  test "email is normalized to lowercase" do
    user = User.new(email: "TEST@EXAMPLE.COM", password: "Password123")
    user.valid?
    assert_equal "test@example.com", user.email
  end

  test "email whitespace is stripped" do
    user = User.new(email: "  test@example.com  ", password: "Password123")
    user.valid?
    assert_equal "test@example.com", user.email
  end

  # Email validation tests
  test "email must be present" do
    user = User.new(email: nil, password: "Password123")
    assert_not user.valid?
    assert_includes user.errors[:email], "can't be blank"
  end

  test "email must be valid format" do
    invalid_emails = [
      "notanemail",
      "@example.com",
      "test@",
      "test @example.com",
      "test@ example.com"
    ]

    invalid_emails.each do |invalid_email|
      user = User.new(email: invalid_email, password: "Password123")
      assert_not user.valid?, "#{invalid_email} should be invalid"
      assert_includes user.errors[:email], "must be a valid email address"
    end
  end

  test "email must not exceed 254 characters" do
    # Create an email that's 255 characters (243 a's + @ + example.com = 255)
    long_email = "#{'a' * 243}@example.com"
    user = User.new(email: long_email, password: "Password123")
    assert_not user.valid?, "Email with #{long_email.length} characters should be invalid"
    assert_includes user.errors[:email], "is too long (maximum is 254 characters)"
  end

  test "email within 254 characters is valid" do
    # Create an email that's exactly 254 characters
    valid_email = "#{'a' * 239}@example.com"
    user = User.new(email: valid_email, password: "Password123")
    user.skip_confirmation! # Skip confirmation for this test
    assert user.valid?
  end

  # Disposable email domain tests
  test "disposable email domains are rejected" do
    disposable_emails = [
      "test@mailinator.com",
      "test@guerrillamail.com",
      "test@10minutemail.com",
      "test@temp-mail.org",
      "test@yopmail.com"
    ]

    disposable_emails.each do |disposable_email|
      user = User.new(email: disposable_email, password: "Password123")
      assert_not user.valid?, "#{disposable_email} should be rejected"
      assert user.errors[:email].any? { |msg| msg.include?("disposable email provider") },
             "Expected disposable email error, got: #{user.errors[:email]}"
    end
  end

  test "non-disposable email domains are accepted" do
    valid_emails = [
      "test@gmail.com",
      "test@outlook.com",
      "test@yahoo.com",
      "test@company.com"
    ]

    valid_emails.each do |valid_email|
      user = User.new(email: valid_email, password: "Password123")
      user.skip_confirmation! # Skip confirmation for this test
      assert user.valid?, "#{valid_email} should be valid"
    end
  end

  # Case-insensitive uniqueness tests
  test "email uniqueness is case-insensitive" do
    user1 = User.new(email: "test@example.com", password: "Password123")
    user1.skip_confirmation!
    user1.save!

    user2 = User.new(email: "TEST@EXAMPLE.COM", password: "Password456")
    assert_not user2.valid?
    assert_includes user2.errors[:email], "has already been taken"
  end

  # Password complexity tests
  test "password must be at least 10 characters" do
    user = User.new(email: "test@example.com", password: "Pass123")
    assert_not user.valid?
    assert_includes user.errors[:password], "is too short (minimum is 10 characters)"
  end

  test "password must include at least one letter" do
    user = User.new(email: "test@example.com", password: "1234567890")
    assert_not user.valid?
    assert_includes user.errors[:password], "must include at least one letter and one number"
  end

  test "password must include at least one number" do
    user = User.new(email: "test@example.com", password: "PasswordOnly")
    assert_not user.valid?
    assert_includes user.errors[:password], "must include at least one letter and one number"
  end

  test "valid password with letter and number is accepted" do
    user = User.new(email: "test@example.com", password: "Password123")
    user.skip_confirmation! # Skip confirmation for this test
    assert user.valid?
  end

  test "password with special characters is accepted" do
    user = User.new(email: "test@example.com", password: "Password123!@#")
    user.skip_confirmation! # Skip confirmation for this test
    assert user.valid?
  end

  # Confirmable tests
  test "new user is not confirmed by default" do
    user = User.new(email: "test@example.com", password: "Password123")
    assert_not user.confirmed?
  end

  test "confirmed? returns true after confirmation" do
    user = User.new(email: "test123@example.com", password: "Password123")
    user.skip_confirmation_notification!
    user.save!
    user.confirm
    assert user.confirmed?
  end
end
