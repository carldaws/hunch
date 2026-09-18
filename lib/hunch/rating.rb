module Hunch
  class Rating
    include Comparable

    attr_reader :position, :levels, :probabilities, :confidence

    def initialize(position:, levels:, probabilities:, confidence: nil)
      @position = position.to_f
      @levels = levels.freeze
      @probabilities = probabilities.freeze
      @confidence = confidence
    end

    def level
      levels[position.round.clamp(0, levels.size - 1)]
    end

    def <=>(other)
      case other
      when Rating then position <=> other.position
      when Numeric then position <=> other
      when Symbol
        index = levels.index(other)
        index && position <=> index
      end
    end

    def ==(other)
      other.is_a?(Symbol) ? level == other : super
    end

    def to_sym = level
    def to_f = position

    def inspect
      "#<Hunch::Rating #{level} (#{position.round(2)})>"
    end
  end
end
