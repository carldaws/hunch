require "test_helper"

class ErrorTriageTest < ActiveSupport::TestCase
  test "pages when the error rates page" do
    stub_hunch(answer: :page)
    level = ErrorTriage.new.report(RuntimeError.new("payments are down"), handled: false)
    assert_equal :page, level
  end

  test "stays quiet on known noise" do
    stub_hunch(answer: :ignore)
    level = ErrorTriage.new.report(IOError.new("broken pipe"), handled: true)
    assert_equal :ignore, level
  end
end
