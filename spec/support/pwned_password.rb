require "webmock/rspec"

RSpec.configure do |config|
  config.before(:each) do
    next if ENV["USE_REAL_APIS"] == "true"

    stub_request(:get, %r{\Ahttps://api\.pwnedpasswords\.com/range/}).to_return(
      status: 200,
      body: "",
      headers: {}
    )
  end
end
