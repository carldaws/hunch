module Hunch
  class Decision
    attr_reader :questions

    def initialize
      @questions = {}
    end

    Configuration::LEVELS.each_key do |level|
      define_method(:"#{level}?") do |key, question, yes: nil, no: nil|
        noul(key, question, yes:, no:, threshold: Hunch.configuration.levels.fetch(level))
      end
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

    def custom_level(name)
      return unless name.to_s.end_with?("?")

      level = name.to_s.delete_suffix("?").to_sym
      Hunch.configuration.levels.key?(level) ? level : nil
    end

    def method_missing(name, *args, **options)
      level = custom_level(name)
      return super unless level

      key, question = args
      noul(key, question, **options, threshold: Hunch.configuration.levels.fetch(level))
    end

    def respond_to_missing?(name, include_private = false)
      !custom_level(name).nil? || super
    end

    def noul(key, question, yes: nil, no: nil, threshold:)
      add Questions::Noul.new(key: key.to_sym, question:, yes:, no:, threshold:)
    end

    def describe(bare, described)
      bare.to_h { |name| [name.to_sym, name.to_s.tr("_", " ")] }.merge(described)
    end

    def add(question)
      if Result::RESERVED_KEYS.include?(question.key)
        raise ArgumentError, "#{question.key} is reserved on results; choose another key"
      end
      raise ArgumentError, "duplicate question key #{question.key}" if @questions.key?(question.key)

      @questions[question.key] = question
      self
    end
  end
end
