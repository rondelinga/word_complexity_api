require "rails_helper"

RSpec.describe Dictionary::Lookup do
  subject(:lookup) { described_class.new(cache:) }

  let(:cache) { ActiveSupport::Cache::MemoryStore.new }

  it "returns word stats and caches them" do
    stub = stub_dictionary("happy", fixture: "happy")

    2.times { expect(lookup.call("happy")).to eq(Dictionary::WordStats.new(synonyms: 4, antonyms: 2, definitions: 4)) }
    expect(stub).to have_been_requested.once
  end

  it "caches not-found answers" do
    stub = stub_dictionary_not_found("qwzxqv")

    2.times { expect { lookup.call("qwzxqv") }.to raise_error(Dictionary::Client::WordNotFound) }
    expect(stub).to have_been_requested.once
  end

  it "does not cache transient failures" do
    stub_request(:get, dictionary_url("happy"))
      .to_return({ status: 503 }, { status: 503 }, { status: 503 }, { status: 200, body: dictionary_fixture("happy") })

    expect { lookup.call("happy") }.to raise_error(Dictionary::Client::Unavailable)
    expect(lookup.call("happy").definitions).to eq(4)
  end
end
