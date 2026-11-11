# Parses and validates the POST /complexity-score payload: a JSON array of words.
# Words are normalized (trimmed, downcased, inner whitespace squeezed) and
# de-duplicated while preserving the original order.
class ComplexityRequest
  include ActiveModel::Validations

  WORD_FORMAT = /\A\p{L}+(?:['’\- ]\p{L}+)*\z/

  class MalformedJson < StandardError; end

  attr_reader :raw, :words

  validate :validate_payload

  def self.from_json(body)
    new(JSON.parse(body.presence || "null"))
  rescue JSON::ParserError => e
    raise MalformedJson, e.message
  end

  def initialize(payload)
    @raw = payload
    @words = []
  end

  private

  def config
    Rails.configuration.x.complexity
  end

  def validate_payload
    unless raw.is_a?(Array)
      errors.add(:base, "Request body must be a JSON array of words")
      return
    end

    if raw.empty?
      errors.add(:base, "At least one word is required")
      return
    end

    if raw.size > config.max_words
      errors.add(:base, "No more than #{config.max_words} words are allowed per request")
      return
    end

    raw.each_with_index { |value, index| validate_word(value, index) }
    @words = raw.map { |w| normalize(w) }.uniq if errors.empty?
  end

  def validate_word(value, index)
    unless value.is_a?(String)
      errors.add(:base, "Element at index #{index} must be a string")
      return
    end

    word = normalize(value)
    if word.empty?
      errors.add(:base, "Element at index #{index} must not be blank")
    elsif word.length > config.max_word_length
      errors.add(:base, "Element at index #{index} exceeds #{config.max_word_length} characters")
    elsif !word.match?(WORD_FORMAT)
      errors.add(:base, "Element at index #{index} (#{value.inspect}) is not a valid word")
    end
  end

  def normalize(value)
    value.strip.squeeze(" ").downcase
  end
end
