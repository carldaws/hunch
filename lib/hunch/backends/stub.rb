module Hunch
  module Backends
    class Stub
      attr_reader :calls

      def initialize(default: nil, **answers)
        @answers = answers
        @default = default
        @calls = []
      end

      def decide(state:, questions:)
        @calls << { state:, questions: }
        answers = questions.to_h do |key, question|
          [key.to_s, answer_for(key, question)]
        end
        { "answers" => answers, "model" => "stub" }
      end

      private

      def answer_for(key, question)
        value = @answers.fetch(key, @default)
        if value.nil?
          raise MissingStubAnswer,
            "no stubbed answer for #{key.inspect}: Stub.new(#{key}: ...) or pass default:"
        end

        case question.type
        when :noul then noul(value)
        when :choice then choice(value, question)
        when :rate then rate(value, question)
        end
      end

      def noul(value)
        probability =
          case value
          when true then 1.0
          when false then 0.0
          when Numeric then value.to_f
          else raise ArgumentError, "chance stub must be true, false, or a probability"
          end
        { "type" => "noul", "noul" => probability }
      end

      def choice(value, question)
        probabilities =
          case value
          when Symbol then question.options.keys.to_h { |option| [option.to_s, option == value ? 1.0 : 0.0] }
          when Hash then value.transform_keys(&:to_s).transform_values(&:to_f)
          else raise ArgumentError, "pick stub must be a symbol or a probabilities hash"
          end
        winner = probabilities.max_by { |_, p| p }.first
        { "type" => "choice", "choice" => winner, "probabilities" => probabilities, "confidence" => probabilities[winner] }
      end

      def rate(value, question)
        levels = question.levels.keys
        position =
          case value
          when Symbol
            levels.index(value) or raise ArgumentError, "#{value.inspect} is not a level of #{question.key}"
          when Numeric then value.to_f
          else raise ArgumentError, "rate stub must be a level symbol or a position"
          end
        nearest = position.round.clamp(0, levels.size - 1)
        probabilities = levels.each_index.to_h { |i| [i.to_s, i == nearest ? 1.0 : 0.0] }
        { "type" => "score", "score" => position.to_f, "probabilities" => probabilities, "confidence" => 1.0 }
      end
    end
  end
end
