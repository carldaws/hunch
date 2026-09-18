module Hunch
  class Result
    attr_reader :model, :usage

    def initialize(questions:, answers:, model: nil, usage: nil)
      @model = model
      @usage = usage
      @values = {}
      questions.each do |key, question|
        raw = answers[key.to_s] || answers[key]
        raise Error, "backend returned no answer for #{key}" unless raw

        build(key, question, raw)
      end
    end

    def [](key)
      @values.fetch(key.to_sym)
    end

    def to_h = @values.dup

    private

    def build(key, question, raw)
      case question.type
      when :noul then build_noul(key, question, raw)
      when :choice then build_choice(key, raw)
      when :rate then build_rate(key, question, raw)
      end
    end

    def build_noul(key, question, raw)
      probability = raw["noul"].to_f
      set(key, probability)
      define(:"#{key}?") { probability >= question.threshold }
    end

    def build_choice(key, raw)
      probabilities = (raw["probabilities"] || {}).transform_keys(&:to_sym)
      choice = raw["choice"]&.to_sym || probabilities.max_by { |_, p| p }&.first
      set(key, choice)
      define(:"#{key}_probabilities") { probabilities }
      define(:"#{key}_confidence") { raw["confidence"] }
    end

    def build_rate(key, question, raw)
      levels = question.levels.keys
      by_index = raw["probabilities"] || {}
      probabilities = levels.each_with_index.to_h do |level, i|
        [level, (by_index[i.to_s] || by_index[i] || 0.0).to_f]
      end
      set(key, Rating.new(position: raw["score"], levels:, probabilities:, confidence: raw["confidence"]))
    end

    def set(key, value)
      @values[key.to_sym] = value
      define(key.to_sym) { value }
    end

    def define(name, &block)
      define_singleton_method(name, &block)
    end
  end
end
