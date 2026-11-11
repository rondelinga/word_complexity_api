module Dictionary
  # Thin HTTP wrapper around https://dictionaryapi.dev.
  # Translates transport/HTTP failures into a small set of domain errors.
  class Client
    class Error < StandardError; end
    # The dictionary has no entry for the word (HTTP 404). Permanent.
    class WordNotFound < Error; end
    # Timeouts, connection failures, 429 and 5xx. Worth retrying later.
    class Unavailable < Error; end
    # The API answered with something we can't interpret. Permanent.
    class InvalidResponse < Error; end

    RETRIABLE_STATUSES = [ 429, 500, 502, 503, 504 ].freeze

    def initialize(config: Rails.configuration.x.dictionary_api, adapter: Faraday.default_adapter)
      @config = config
      @adapter = adapter
    end

    # Returns the parsed JSON array of entries for the word.
    def entries(word)
      response = connection.get(ERB::Util.url_encode(word))
      handle(response, word)
    rescue Faraday::TimeoutError, Faraday::ConnectionFailed => e
      raise Unavailable, "Dictionary API unreachable: #{e.class}: #{e.message}"
    rescue Faraday::Error => e
      raise Unavailable, "Dictionary API request failed: #{e.class}: #{e.message}"
    end

    private

    attr_reader :config

    def handle(response, word)
      case response.status
      when 200
        parse(response.body)
      when 404
        raise WordNotFound, "No definitions found for #{word.inspect}"
      when *RETRIABLE_STATUSES
        raise Unavailable, "Dictionary API responded with HTTP #{response.status}"
      else
        raise InvalidResponse, "Unexpected HTTP #{response.status} from Dictionary API"
      end
    end

    def parse(body)
      data = JSON.parse(body)
      raise InvalidResponse, "Expected a JSON array of entries" unless data.is_a?(Array)

      data
    rescue JSON::ParserError => e
      raise InvalidResponse, "Malformed JSON from Dictionary API: #{e.message}"
    end

    def connection
      @connection ||= Faraday.new(url: "#{config.base_url.chomp('/')}/") do |f|
        f.options.open_timeout = config.open_timeout
        f.options.timeout = config.read_timeout
        f.headers["Accept"] = "application/json"
        f.headers["User-Agent"] = "WordComplexityApi/1.0"
        # Short in-request retries smooth over blips. A Retry-After longer than
        # max_interval is not slept on (it would block a worker thread); the
        # background job retries later with exponential backoff instead.
        f.request :retry,
          max: config.max_retries,
          interval: config.retry_interval,
          max_interval: config.max_retry_interval,
          backoff_factor: 2,
          interval_randomness: 0.5,
          retry_statuses: RETRIABLE_STATUSES,
          methods: %i[get],
          exceptions: [ Faraday::TimeoutError, Faraday::ConnectionFailed, Faraday::RetriableResponse ]
        f.adapter @adapter
      end
    end
  end
end
