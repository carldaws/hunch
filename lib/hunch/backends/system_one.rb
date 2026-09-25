require "net/http"
require "json"
require "uri"

module Hunch
  module Backends
    class SystemOne
      def initialize(url:, api_key:, model:, timeout: 5, open_timeout: 2, max_retries: 2, transport: nil, sleeper: nil)
        @url = url
        @api_key = api_key
        @model = model
        @timeout = timeout
        @open_timeout = open_timeout
        @max_retries = max_retries
        @transport = transport || method(:http_post)
        @sleeper = sleeper || ->(seconds) { sleep(seconds) }
      end

      def decide(state:, questions:)
        raise ConfigurationError, "no API key for #{@url}" if @api_key.nil? || @api_key.empty?

        payload = {
          "state" => state,
          "model" => @model,
          "questions" => questions.to_h { |key, question| [key.to_s, question.payload] }
        }
        with_retries { handle(*@transport.call(payload)) }
      end

      private

      def with_retries
        attempts = 0
        begin
          attempts += 1
          yield
        rescue RateLimitError, OverloadedError, ServerError, TimeoutError, ConnectionError => e
          raise if attempts > @max_retries

          @sleeper.call(e.respond_to?(:retry_after) && e.retry_after || backoff(attempts))
          retry
        end
      end

      def backoff(attempt)
        (0.5 * (2**(attempt - 1))) + rand * 0.25
      end

      def handle(status, headers, body)
        case status
        when 200..299 then JSON.parse(body)
        when 401 then raise AuthenticationError, error_message(body, "missing or invalid API key")
        when 422 then raise ValidationError, error_message(body, "invalid request")
        when 429 then raise RateLimitError.new(error_message(body, "rate limited"), retry_after: retry_after(headers))
        when 529 then raise OverloadedError, error_message(body, "service overloaded")
        when 500..599 then raise ServerError, "server error (#{status})"
        else raise APIError, error_message(body, "unexpected response (#{status})")
        end
      end

      def error_message(body, fallback)
        parsed = JSON.parse(body)
        error = parsed["error"] || parsed["message"] || fallback
        error.is_a?(Hash) ? error["message"] || fallback : error
      rescue JSON::ParserError, TypeError
        fallback
      end

      def retry_after(headers)
        value = headers["retry-after"] || headers["Retry-After"]
        value&.to_f&.nonzero?
      end

      def http_post(payload)
        uri = URI(@url)
        request = Net::HTTP::Post.new(uri)
        request["Authorization"] = "Bearer #{@api_key}"
        request["Content-Type"] = "application/json"
        request["User-Agent"] = "hunch-ruby/#{VERSION}"
        request.body = JSON.generate(payload)

        response = Net::HTTP.start(
          uri.host, uri.port,
          use_ssl: uri.scheme == "https",
          open_timeout: @open_timeout,
          read_timeout: @timeout
        ) { |http| http.request(request) }

        [response.code.to_i, response.each_header.to_h, response.body]
      rescue Net::OpenTimeout, Net::ReadTimeout => e
        raise TimeoutError, e.message
      rescue SocketError, SystemCallError, EOFError, OpenSSL::SSL::SSLError => e
        raise ConnectionError, e.message
      end
    end
  end
end
