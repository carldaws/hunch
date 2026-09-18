require "test_helper"

class SignupTest < ActiveSupport::TestCase
  test "valid when the fields read like a human wrote them" do
    stub_hunch(answer: 0.95)
    signup = Signup.new(email: "carl@example.com", display_name: "Carl Dawson",
                        bio: "Building small products on the Isle of Wight.")
    assert signup.valid?
  end

  test "invalid when the bio reads like spam" do
    stub_hunch(answer: 0.4)
    signup = Signup.new(email: "x@example.com", display_name: "BEST-CRYPTO-DEALS.example",
                        bio: "BUY CHEAP GOLD CLICK HERE best prices!!!")
    assert_not signup.valid?
    assert_equal ["doesn't look like a name"], signup.errors[:display_name]
    assert_equal ["reads like spam"], signup.errors[:bio]
  end

  test "blank optional fields skip the API entirely" do
    stub = stub_hunch
    assert Signup.new(email: "carl@example.com").valid?
    assert_empty stub.calls
  end

  test "api failure fails open" do
    Hunch.backend = Object.new.tap do |backend|
      def backend.decide(state:, questions:, model: nil) = raise Hunch::TimeoutError, "timed out"
    end
    assert Signup.new(email: "carl@example.com", bio: "whatever").valid?
  end
end
