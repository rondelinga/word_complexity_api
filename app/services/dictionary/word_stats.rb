module Dictionary
  # Aggregated counts extracted from a dictionary response.
  #
  # Synonyms and antonyms are collected from both the definition level and the
  # meaning (part of speech) level of every entry and de-duplicated
  # case-insensitively, so a synonym listed in several places counts once.
  WordStats = Data.define(:synonyms, :antonyms, :definitions) do
    def self.from_entries(entries)
      synonyms = Set.new
      antonyms = Set.new
      definitions = 0

      Array(entries).each do |entry|
        Array(entry.is_a?(Hash) ? entry["meanings"] : nil).each do |meaning|
          next unless meaning.is_a?(Hash)

          collect(synonyms, meaning["synonyms"])
          collect(antonyms, meaning["antonyms"])

          Array(meaning["definitions"]).each do |definition|
            next unless definition.is_a?(Hash)

            definitions += 1
            collect(synonyms, definition["synonyms"])
            collect(antonyms, definition["antonyms"])
          end
        end
      end

      new(synonyms: synonyms.size, antonyms: antonyms.size, definitions:)
    end

    def self.collect(set, values)
      Array(values).each do |value|
        normalized = value.to_s.strip.downcase
        set << normalized unless normalized.empty?
      end
    end
    private_class_method :collect

    def self.from_h(hash)
      new(**hash.symbolize_keys.slice(:synonyms, :antonyms, :definitions))
    end
  end
end
