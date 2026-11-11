require "rails_helper"

RSpec.describe ComplexityScore do
  def stats(synonyms:, antonyms:, definitions:)
    Dictionary::WordStats.new(synonyms:, antonyms:, definitions:)
  end

  it "divides synonyms plus antonyms by the number of definitions" do
    expect(described_class.calculate(stats(synonyms: 4, antonyms: 2, definitions: 4))).to eq(BigDecimal("1.5"))
  end

  it "rounds to two decimal places" do
    expect(described_class.calculate(stats(synonyms: 1, antonyms: 0, definitions: 3))).to eq(BigDecimal("0.33"))
  end

  it "returns zero when there are no synonyms or antonyms" do
    expect(described_class.calculate(stats(synonyms: 0, antonyms: 0, definitions: 5))).to eq(0)
  end

  it "raises when there are no definitions" do
    expect { described_class.calculate(stats(synonyms: 1, antonyms: 1, definitions: 0)) }
      .to raise_error(ComplexityScore::NoDefinitions)
  end
end
