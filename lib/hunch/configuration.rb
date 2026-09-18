module Hunch
  class Configuration
    LEVELS = { possible: 0.25, likely: 0.5, probable: 0.75, almost_certain: 0.93 }.freeze

    attr_accessor :api_key, :model, :url, :timeout, :open_timeout, :max_retries, :levels
    attr_writer :backend

    def initialize
      @api_key = ENV["TYPESAFE_API_KEY"]
      @model = "jev-latest"
      @url = "https://api.typesafe.ai/v1/systemone"
      @timeout = 5
      @open_timeout = 2
      @max_retries = 2
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
        raise ArgumentError, "at_least must be a number or a level name"
      end
    end

    def backend
      @backend = resolve(@backend)
    end

    private

    def resolve(backend)
      case backend
      when nil, :jev then Backends::Jev.new(self)
      when :stub then Backends::Stub.new
      when Symbol then raise ConfigurationError, "unknown backend #{backend.inspect}"
      else backend
      end
    end
  end
end
