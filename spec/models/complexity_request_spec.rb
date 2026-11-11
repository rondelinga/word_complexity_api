require "rails_helper"

RSpec.describe ComplexityRequest do
  def build(payload)
    described_class.new(payload)
  end

  def error_messages(payload)
    build(payload).tap(&:valid?).errors.full_messages
  end

  it "accepts an array of words and normalizes/de-duplicates them in order" do
    request = build([ " Happy ", "joyful", "HAPPY", "ice  cream", "well-being", "don't" ])

    expect(request).to be_valid
    expect(request.words).to eq([ "happy", "joyful", "ice cream", "well-being", "don't" ])
  end

  it "parses a JSON body" do
    expect(described_class.from_json('["sad"]')).to be_valid
  end

  it "raises MalformedJson for invalid JSON" do
    expect { described_class.from_json("[sad") }.to raise_error(described_class::MalformedJson)
  end

  it "rejects an empty body" do
    expect(described_class.from_json("")).not_to be_valid
  end

  it "rejects non-array payloads" do
    request = build({ "words" => [ "happy" ] })

    expect(request).not_to be_valid
    expect(request.errors.full_messages).to include("Request body must be a JSON array of words")
  end

  it "rejects an empty array" do
    expect(error_messages([])).to include("At least one word is required")
  end

  it "rejects too many words" do
    words = Array.new(Rails.configuration.x.complexity.max_words + 1) { "word" }

    expect(error_messages(words).first).to match(/No more than/)
  end

  it "reports every invalid element with its index" do
    messages = error_messages([ "ok", 42, "  ", "abc123", "a" * 100 ])

    expect(messages).to contain_exactly(
      "Element at index 1 must be a string",
      "Element at index 2 must not be blank",
      %(Element at index 3 ("abc123") is not a valid word),
      "Element at index 4 exceeds #{Rails.configuration.x.complexity.max_word_length} characters"
    )
  end
end
