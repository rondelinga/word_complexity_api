# score = (synonyms + antonyms) / definitions
module ComplexityScore
  PRECISION = 2

  class NoDefinitions < StandardError; end

  def self.calculate(stats)
    raise NoDefinitions, "Cannot score a word without definitions" if stats.definitions.zero?

    ((stats.synonyms + stats.antonyms).to_d / stats.definitions).round(PRECISION)
  end
end
