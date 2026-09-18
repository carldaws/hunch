require "test_helper"

class RatingTest < Minitest::Test
  LEVELS = %i[ignore notify page].freeze

  def build(position, probabilities: { ignore: 0.1, notify: 0.5, page: 0.4 }, confidence: 0.8)
    Hunch::Rating.new(position:, levels: LEVELS, probabilities:, confidence:)
  end

  def test_level_rounds_to_nearest
    assert_equal :notify, build(1.4).level
    assert_equal :page, build(1.6).level
  end

  def test_level_clamps_to_the_scale
    assert_equal :ignore, build(-0.6).level
    assert_equal :page, build(2.7).level
  end

  def test_compares_against_numbers
    assert_operator build(1.4), :>, 1.0
    assert_operator build(1.4), :<, 2
  end

  def test_compares_against_level_symbols
    assert_operator build(1.4), :>=, :notify
    refute_operator build(1.4), :>=, :page
  end

  def test_equals_its_level_symbol
    assert_equal build(1.4), :notify
    refute_equal build(1.4), :page
  end

  def test_compares_against_other_scores
    assert_operator build(1.4), :<, build(1.9)
  end

  def test_unknown_symbol_comparison_raises
    assert_raises(ArgumentError) { build(1.4) < :nonsense }
  end

  def test_conversions
    score = build(1.4)
    assert_equal :notify, score.to_sym
    assert_in_delta 1.4, score.to_f
  end
end
