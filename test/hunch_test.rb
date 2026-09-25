require "test_helper"

class HunchTest < Minitest::Test
  include StubHelpers

  def test_chance_returns_a_float
    stub_backend(answer: 0.92)
    assert_in_delta 0.92, Hunch.chance("does this convey urgency?", given: "URGENT!!")
  end

  def test_likely_collapses_at_the_default_threshold
    stub_backend(answer: 0.6)
    assert Hunch.likely?("is it?", given: "state")
  end

  def test_the_predicate_family_collapses_at_each_level
    { possibly?: 0.25, likely?: 0.5, probably?: 0.75, almost_certainly?: 0.93 }.each do |predicate, threshold|
      stub_backend(answer: threshold)
      assert Hunch.public_send(predicate, "is it?", given: "state"), predicate

      stub_backend(answer: threshold - 0.01)
      refute Hunch.public_send(predicate, "is it?", given: "state"), predicate
    end
  end

  def test_default_thresholds_are_adjustable
    Hunch.configure { |c| c.levels[:probably] = 0.9 }
    stub_backend(answer: 0.8)
    refute Hunch.probably?("is it?", given: "state")

    result = Hunch.decide(given: "state") { |q| q.probably? :answer, "is it?" }
    refute result.answer?
  end

  def test_custom_levels_become_predicates
    Hunch.configure { |c| c.levels[:paranoid] = 0.99 }
    stub_backend(answer: 0.95)
    refute Hunch.paranoid?("is it?", given: "state")
    assert_respond_to Hunch, :paranoid?
  end

  def test_unknown_predicates_still_raise
    stub_backend(answer: 0.95)
    assert_raises(NoMethodError) { Hunch.sure_ish?("is it?", given: "state") }
  end

  def test_batch_rejects_unknown_predicates
    stub_backend(fraud: 0.7)
    assert_raises(NoMethodError) do
      Hunch.decide(given: "order") { |q| q.sure_ish? :fraud, "fraud?" }
    end
  end

  def test_pick_with_described_options
    stub_backend(answer: :billing)
    team = Hunch.pick(billing: "payments and invoices", support: "product questions",
                      given: "my invoice is wrong")
    assert_equal :billing, team
  end

  def test_pick_with_bare_symbols
    stub = stub_backend(answer: :spam)
    label = Hunch.pick(:ham, :spam, given: "BUY NOW!!!")
    assert_equal :spam, label
    question = stub.calls.first[:questions][:answer]
    assert_equal({ ham: "ham", spam: "spam" }, question.options)
  end

  def test_bare_symbols_humanize_underscores
    stub = stub_backend(answer: :not_spam)
    Hunch.pick(:not_spam, :spam, given: "hello")
    assert_equal "not spam", stub.calls.first[:questions][:answer].options[:not_spam]
  end

  def test_rate_returns_a_rating
    stub_backend(answer: :notify)
    severity = Hunch.rate(:ignore, :notify, :page, given: "NoMethodError on nil",
                           question: "how severe?")
    assert_instance_of Hunch::Rating, severity
    assert_equal :notify, severity.level
  end

  def test_rate_mixes_bare_and_described_levels
    stub = stub_backend(answer: :page)
    Hunch.rate(:ignore, :notify, page: "users are impacted right now", given: "outage")
    levels = stub.calls.first[:questions][:answer].levels
    assert_equal({ ignore: "ignore", notify: "notify", page: "users are impacted right now" }, levels)
  end

  def test_decide_batches_questions_into_one_backend_call
    stub = stub_backend(urgent: 0.9, team: :billing, mood: :calm)
    result = Hunch.decide(given: "Help! Payouts failing for 3 days.") do |q|
      q.likely? :urgent, "does this convey urgency?"
      q.pick :team, billing: "payments", technical: "bugs"
      q.rate :mood, :calm, :frustrated, :livid
    end

    assert_equal 1, stub.calls.size
    assert_in_delta 0.9, result.urgent
    assert result.urgent?
    assert_equal :billing, result.team
    assert_equal :calm, result.mood.level
  end

  def test_decide_result_exposes_choice_probabilities
    stub_backend(team: { billing: 0.85, technical: 0.15 })
    result = Hunch.decide(given: "state") do |q|
      q.pick :team, billing: "payments", technical: "bugs"
    end

    assert_equal :billing, result.team
    assert_in_delta 0.85, result.team_probabilities[:billing]
    assert_in_delta 0.85, result.team_confidence
  end

  def test_batch_predicates_set_each_questions_threshold
    { possibly?: 0.25, likely?: 0.5, probably?: 0.75, almost_certainly?: 0.93 }.each do |predicate, threshold|
      stub_backend(at_threshold: threshold, below_threshold: threshold - 0.01)
      result = Hunch.decide(given: "order") do |q|
        q.public_send(predicate, :at_threshold, "is this fraudulent?")
        q.public_send(predicate, :below_threshold, "is this fraudulent?")
      end

      assert_in_delta threshold, result.at_threshold
      assert result.at_threshold?, predicate
      refute result.below_threshold?, predicate
    end
  end

  def test_batch_custom_level_predicates
    Hunch.configure { |c| c.levels[:paranoid] = 0.99 }
    stub_backend(fraud: 0.95)
    result = Hunch.decide(given: "order") { |q| q.paranoid? :fraud, "fraud?" }
    refute result.fraud?
  end

  def test_decide_rejects_duplicate_keys
    stub_backend(default: 0.5)
    assert_raises(ArgumentError) do
      Hunch.decide(given: "state") do |q|
        q.likely? :x, "one"
        q.likely? :x, "two"
      end
    end
  end

  def test_decide_requires_questions
    stub_backend
    assert_raises(ArgumentError) { Hunch.decide(given: "state") { |_q| } }
  end

  def test_pick_requires_two_options
    stub_backend(default: :only)
    assert_raises(ArgumentError) do
      Hunch.decide(given: "state") { |q| q.pick :choice, :only }
    end
  end

  def test_result_indexing_and_to_h
    stub_backend(urgent: 0.9)
    result = Hunch.decide(given: "state") { |q| q.likely? :urgent, "urgent?" }
    assert_in_delta 0.9, result[:urgent]
    assert_equal %i[urgent], result.to_h.keys
  end

  def test_missing_backend_raises
    error = assert_raises(Hunch::ConfigurationError) { Hunch.chance("question?", given: "state") }
    assert_match(/no backend/, error.message)
  end

  def test_answer_outside_the_options_raises
    Hunch.backend = answering("team" => { "type" => "choice", "choice" => "legal" })
    error = assert_raises(Hunch::InvalidAnswerError) do
      Hunch.decide(given: "state") { |q| q.pick :team, :billing, :technical }
    end
    assert_equal "team needs one of billing, technical, got :legal", error.message
  end

  def test_missing_probability_raises
    Hunch.backend = answering("urgent" => { "type" => "noul" })
    error = assert_raises(Hunch::InvalidAnswerError) { Hunch.decide(given: "state") { |q| q.likely? :urgent, "?" } }
    assert_equal "urgent needs a probability, got nil", error.message
  end

  def test_probability_out_of_range_raises
    Hunch.backend = answering("urgent" => { "type" => "noul", "noul" => 1.4 })
    assert_raises(Hunch::InvalidAnswerError) { Hunch.decide(given: "state") { |q| q.likely? :urgent, "?" } }
  end

  def test_missing_position_raises
    Hunch.backend = answering("mood" => { "type" => "score", "score" => nil })
    error = assert_raises(Hunch::InvalidAnswerError) { Hunch.decide(given: "state") { |q| q.rate :mood, :calm, :livid } }
    assert_equal "mood needs a position, got nil", error.message
  end

  def test_missing_answer_is_an_api_error
    Hunch.backend = answering({})
    assert_raises(Hunch::APIError) { Hunch.chance("question?", given: "state") }
  end

  private

  def answering(answers)
    Object.new.tap do |backend|
      backend.define_singleton_method(:decide) { |state:, questions:| { "answers" => answers } }
    end
  end
end
