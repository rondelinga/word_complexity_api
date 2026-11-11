module Dictionary
  # Fetches WordStats for a word, caching both hits and "not found" answers
  # so repeated words across jobs don't hit the third-party API again.
  # Transient failures are never cached.
  class Lookup
    CACHE_VERSION = "v1".freeze

    def initialize(client: Client.new, cache: Rails.cache, config: Rails.configuration.x.dictionary_api)
      @client = client
      @cache = cache
      @config = config
    end

    def call(word)
      key = cache_key(word)
      cached = @cache.read(key)
      return from_cache(cached, word) if cached

      stats = WordStats.from_entries(@client.entries(word))
      @cache.write(key, { "found" => true, "stats" => stats.to_h }, expires_in: @config.cache_ttl)
      stats
    rescue Client::WordNotFound
      @cache.write(key, { "found" => false }, expires_in: @config.not_found_cache_ttl)
      raise
    end

    private

    def from_cache(cached, word)
      raise Client::WordNotFound, "No definitions found for #{word.inspect} (cached)" unless cached["found"]

      WordStats.from_h(cached["stats"])
    end

    def cache_key(word)
      "dictionary/#{CACHE_VERSION}/#{word}"
    end
  end
end
