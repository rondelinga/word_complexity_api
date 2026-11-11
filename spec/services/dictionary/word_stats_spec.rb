require "rails_helper"

RSpec.describe Dictionary::WordStats do
  describe ".from_entries" do
    it "counts definitions and unique synonyms/antonyms across all entries and meanings" do
      stats = described_class.from_entries(JSON.parse(dictionary_fixture("happy")))

      # synonyms: content, joyful, cheerful, happify; antonyms: sad, unhappy
      expect(stats).to eq(described_class.new(synonyms: 4, antonyms: 2, definitions: 4))
    end

    it "returns zeros for an empty response" do
      expect(described_class.from_entries([])).to eq(described_class.new(synonyms: 0, antonyms: 0, definitions: 0))
    end

    it "tolerates missing or malformed fields" do
      entries = [
        { "word" => "odd" },
        { "meanings" => nil },
        { "meanings" => [ "not a hash", { "definitions" => [ nil, { "definition" => "x", "synonyms" => [ "", " y " ] } ] } ] },
        "garbage"
      ]

      expect(described_class.from_entries(entries)).to eq(described_class.new(synonyms: 1, antonyms: 0, definitions: 1))
    end
  end

  it "round-trips through a hash for caching" do
    stats = described_class.new(synonyms: 1, antonyms: 2, definitions: 3)
    expect(described_class.from_h(stats.to_h.stringify_keys)).to eq(stats)
  end
end
