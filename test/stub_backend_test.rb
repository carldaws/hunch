require "test_helper"

class StubBackendTest < Minitest::Test
  include StubHelpers

  def test_missing_stub_raises_with_guidance
    stub_backend
    error = assert_raises(Hunch::MissingStubAnswer) do
      Hunch.chance("question?", given: "state")
    end
    assert_match(/no stubbed answer/, error.message)
  end

  def test_default_covers_unstubbed_keys
    stub_backend(default: 0.5)
    assert_in_delta 0.5, Hunch.chance("question?", given: "state")
  end

  def test_boolean_shorthand_for_noul
    stub_backend(answer: true)
    assert_in_delta 1.0, Hunch.chance("question?", given: "state")
  end

  def test_rate_stub_by_position
    stub_backend(answer: 1.6)
    reading = Hunch.rate(:low, :mid, :high, given: "state")
    assert_in_delta 1.6, reading.position
    assert_equal :high, reading.level
  end

  def test_rate_stub_rejects_unknown_level
    stub_backend(answer: :nonsense)
    assert_raises(ArgumentError) { Hunch.rate(:low, :high, given: "state") }
  end

  def test_records_calls
    stub = stub_backend(answer: 0.5)
    Hunch.chance("question?", given: "some state")
    assert_equal 1, stub.calls.size
    assert_equal "some state", stub.calls.first[:state]
  end
end
