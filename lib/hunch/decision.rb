module Hunch
  class Decision
    attr_reader :questions

    def initialize
      @questions = {}
    end

    def likely?(key, question, yes: nil, no: nil, over: 0.5)
      threshold = Hunch.configuration.resolve_level(over)
      add Questions::Noul.new(key: key.to_sym, question:, yes:, no:, threshold:)
    end

    def pick(key, *options, question: nil, **described)
      all = describe(options, described)
      raise ArgumentError, "pick needs at least two options" if all.size < 2

      add Questions::Choice.new(key: key.to_sym, question:, options: all)
    end

    def rate(key, *levels, question: nil, **described)
      all = describe(levels, described)
      raise ArgumentError, "rate needs at least two levels" if all.size < 2

      add Questions::Rate.new(key: key.to_sym, question:, levels: all)
    end

    private

    def describe(bare, described)
      bare.to_h { |name| [name.to_sym, name.to_s.tr("_", " ")] }.merge(described)
    end

    def add(question)
      raise ArgumentError, "duplicate question key #{question.key}" if @questions.key?(question.key)

      @questions[question.key] = question
      self
    end
  end
end
