require "test_helper"
require "json"

class SystemOneBackendTest < Minitest::Test
  include StubHelpers

  RESPONSE = {
    "model" => "jev-1.13.0",
    "answers" => {
      "urgent" => { "type" => "noul", "noul" => 0.92 },
      "team" => {
        "type" => "choice", "choice" => "technical",
        "probabilities" => { "billing" => 0.08, "technical" => 0.85, "sales" => 0.07 },
        "confidence" => 0.82
      },
      "mood" => {
        "type" => "score", "score" => 1.6,
        "probabilities" => { "0" => 0.05, "1" => 0.3, "2" => 0.65 },
        "confidence" => 0.78
      }
    },
    "usage" => { "input_tokens" => 312, "output_tokens" => 48 }
  }.freeze

  def questions
    decision = Hunch::Decision.new
    decision.likely? :urgent, "does this convey urgency?", yes: "explicitly time-sensitive", no: "no urgency"
    decision.pick :team, question: "which team?", billing: "payments", technical: "bugs", sales: "pricing"
    decision.rate :mood, question: "how frustrated?", calm: "calm", frustrated: "frustrated", livid: "very angry"
    decision.questions
  end

  def backend(transport:, sleeper: ->(_s) {}, api_key: "test-key")
    Hunch::Backends::SystemOne.new(url: "https://example.test/decisions", api_key:, model: "typesafe/jev-1.13",
                                   transport:, sleeper:)
  end

  def test_payload_matches_the_wire_format
    sent = nil
    jev = backend(transport: ->(payload) { sent = payload; [200, {}, JSON.generate(RESPONSE)] })
    jev.decide(state: "Help! Payouts failing.", questions: questions)

    assert_equal "Help! Payouts failing.", sent["state"]
    assert_equal "typesafe/jev-1.13", sent["model"]
    assert_equal %w[urgent team mood], sent["questions"].keys

    urgent = sent["questions"]["urgent"]
    assert_equal "noul", urgent["type"]
    assert_equal "does this convey urgency?", urgent["instructions"]
    assert_equal({ "true" => "explicitly time-sensitive", "false" => "no urgency" }, urgent["criteria"])

    team = sent["questions"]["team"]
    assert_equal "choice", team["type"]
    assert_equal %w[billing technical sales], team["criteria"].keys

    mood = sent["questions"]["mood"]
    assert_equal "score", mood["type"]
    assert_equal ["calm", "frustrated", "very angry"], mood["criteria"]
  end

  def test_parses_answers_into_a_result
    jev = backend(transport: ->(_p) { [200, {}, JSON.generate(RESPONSE)] })
    raw = jev.decide(state: "state", questions: questions)
    result = Hunch::Result.new(questions:, answers: raw["answers"], model: raw["model"], usage: raw["usage"])

    assert_in_delta 0.92, result.urgent
    assert result.urgent?
    assert_equal :technical, result.team
    assert_in_delta 0.85, result.team_probabilities[:technical]
    assert_equal :livid, result.mood.level
    assert_in_delta 1.6, result.mood.position
    assert_in_delta 0.65, result.mood.probabilities[:livid]
    assert_equal "jev-1.13.0", result.model
  end

  def test_authentication_error_is_not_retried
    attempts = 0
    jev = backend(transport: ->(_p) { attempts += 1; [401, {}, "{}"] })
    assert_raises(Hunch::AuthenticationError) { jev.decide(state: "s", questions: questions) }
    assert_equal 1, attempts
  end

  def test_validation_error_surfaces_the_api_message
    jev = backend(transport: ->(_p) { [422, {}, JSON.generate({ "error" => "criteria must not be empty" })] })
    error = assert_raises(Hunch::ValidationError) { jev.decide(state: "s", questions: questions) }
    assert_equal "criteria must not be empty", error.message
  end

  def test_rate_limit_retries_and_honours_retry_after
    attempts = 0
    slept = []
    transport = lambda do |_p|
      attempts += 1
      attempts < 3 ? [429, { "retry-after" => "0.5" }, "{}"] : [200, {}, JSON.generate(RESPONSE)]
    end
    jev = backend(transport:, sleeper: ->(s) { slept << s })
    raw = jev.decide(state: "s", questions: questions)

    assert_equal 3, attempts
    assert_equal [0.5, 0.5], slept
    assert_equal "jev-1.13.0", raw["model"]
  end

  def test_retries_are_exhausted
    attempts = 0
    jev = backend(transport: ->(_p) { attempts += 1; [503, {}, ""] })
    assert_raises(Hunch::ServerError) { jev.decide(state: "s", questions: questions) }
    assert_equal 3, attempts
  end

  def test_missing_api_key_raises_configuration_error
    [nil, ""].each do |api_key|
      jev = backend(transport: ->(_p) { flunk "no request without a key" }, api_key:)
      error = assert_raises(Hunch::ConfigurationError) { jev.decide(state: "s", questions: questions) }
      assert_equal "no API key for https://example.test/decisions", error.message
    end
  end
end
