module Hunch
  class Configuration
    LEVELS = { possibly: 0.25, likely: 0.5, probably: 0.75, almost_certainly: 0.93 }.freeze

    attr_accessor :levels
    attr_writer :backend

    def initialize
      @levels = LEVELS.dup
      @backend = nil
    end

    def resolve_level(value)
      case value
      when Numeric then value.to_f
      when Symbol
        levels.fetch(value) do
          raise ConfigurationError, "unknown level #{value.inspect}; known levels: #{levels.keys.join(", ")}"
        end
      else
        raise ArgumentError, "level must be a number or a level name"
      end
    end

    def backend
      @backend or raise ConfigurationError,
        "no backend: Hunch.configure { |c| c.backend = Hunch::Backends::SystemOne.new(url:, api_key:, model:) }"
    end
  end
end
