require "test_helper"
require "active_model"

class Signup
  include ActiveModel::Model

  attr_accessor :email, :display_name, :bio

  validates :email, presence: true
  validate :display_name_is_a_name, :bio_reads_like_a_human

  private

  def display_name_is_a_name
    return if display_name.blank?
    return if Hunch.likely?("a plausible human or company name, not an advert or URL", given: display_name)

    errors.add(:display_name, "doesn't look like a name")
  rescue Hunch::APIError
    nil
  end

  def bio_reads_like_a_human
    return if bio.blank?
    return if Hunch.probably?("a genuine human bio, not spam or keyword stuffing", given: bio)

    errors.add(:bio, "reads like spam")
  rescue Hunch::APIError
    nil
  end
end

class RailsValidationTest < Minitest::Test
  include StubHelpers

  def test_valid_when_the_fields_read_like_a_human_wrote_them
    stub_backend(answer: 0.95)
    assert_predicate Signup.new(email: "carl@example.com", display_name: "Carl Dawson",
                                bio: "Building small products."), :valid?
  end

  def test_invalid_when_the_bio_reads_like_spam
    stub_backend(answer: 0.4)
    signup = Signup.new(email: "x@example.com", bio: "BUY CHEAP GOLD CLICK HERE")
    refute_predicate signup, :valid?
    assert_equal ["reads like spam"], signup.errors[:bio]
  end

  def test_blank_fields_are_someone_elses_job
    stub = stub_backend
    assert_predicate Signup.new(email: "carl@example.com"), :valid?
    assert_empty stub.calls
  end

  def test_api_failure_fails_open
    failing = Object.new
    def failing.decide(state:, questions:, model: nil) = raise Hunch::TimeoutError, "timed out"
    Hunch.backend = failing

    assert_predicate Signup.new(email: "carl@example.com", bio: "whatever"), :valid?
  end
end
