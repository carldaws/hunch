module Hunch
  class Error < StandardError; end

  class ConfigurationError < Error; end
  class AuthenticationError < Error; end
  class ValidationError < Error; end
  class APIError < Error; end
  class InvalidAnswerError < APIError; end
  class ServerError < APIError; end
  class OverloadedError < APIError; end
  class TimeoutError < APIError; end
  class ConnectionError < APIError; end

  class RateLimitError < APIError
    attr_reader :retry_after

    def initialize(message = "rate limited", retry_after: nil)
      super(message)
      @retry_after = retry_after
    end
  end

  class MissingStubAnswer < Error; end
end
