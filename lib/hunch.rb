require_relative "hunch/version"
require_relative "hunch/errors"
require_relative "hunch/questions"
require_relative "hunch/rating"
require_relative "hunch/configuration"
require_relative "hunch/decision"
require_relative "hunch/result"
require_relative "hunch/backends/system_one"
require_relative "hunch/backends/stub"

module Hunch
  class << self
    def configure
      yield configuration
      configuration
    end

    def configuration
      @configuration ||= Configuration.new
    end

    def reset_configuration!
      @configuration = nil
    end

    def backend=(backend)
      configuration.backend = backend
    end

    def decide(given:)
      decision = Decision.new
      yield decision
      raise ArgumentError, "decide needs at least one question" if decision.questions.empty?

      ask(decision.questions, given)
    end

    def chance(question, given:, yes: nil, no: nil)
      decide(given:) { |q| q.likely?(:answer, question, yes:, no:) }.answer
    end

    Configuration::LEVELS.each_key do |level|
      define_method(:"#{level}?") do |question, given:, yes: nil, no: nil|
        chance(question, given:, yes:, no:) >= configuration.levels.fetch(level)
      end
    end

    def pick(*options, given:, question: nil, **described)
      decide(given:) { |q| q.pick(:answer, *options, question:, **described) }.answer
    end

    def rate(*levels, given:, question: nil, **described)
      decide(given:) { |q| q.rate(:answer, *levels, question:, **described) }.answer
    end

    private

    def ask(questions, state)
      raw = configuration.backend.decide(state:, questions:)
      Result.new(questions:, answers: raw["answers"] || {}, model: raw["model"], usage: raw["usage"])
    end

    def custom_level(name)
      return unless name.to_s.end_with?("?")

      level = name.to_s.delete_suffix("?").to_sym
      configuration.levels.key?(level) ? level : nil
    end

    def method_missing(name, *args, **options, &block)
      level = custom_level(name)
      return super unless level

      chance(*args, **options) >= configuration.levels.fetch(level)
    end

    def respond_to_missing?(name, include_private = false)
      !custom_level(name).nil? || super
    end
  end
end
