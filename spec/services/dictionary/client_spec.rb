require "rails_helper"

RSpec.describe Dictionary::Client do
  subject(:client) { described_class.new }

  it "returns parsed entries on success" do
    stub_dictionary("happy", fixture: "happy")

    expect(client.entries("happy").first["word"]).to eq("happy")
  end

  it "URL-encodes the word" do
    stub = stub_dictionary("ice cream", body: [])

    client.entries("ice cream")

    expect(stub).to have_been_requested
  end

  it "raises WordNotFound on 404" do
    stub_dictionary_not_found("qwzxqv")

    expect { client.entries("qwzxqv") }.to raise_error(described_class::WordNotFound)
  end

  it "retries transient failures before succeeding" do
    stub_request(:get, dictionary_url("happy"))
      .to_return({ status: 503 }, { status: 200, body: dictionary_fixture("happy") })

    expect(client.entries("happy")).to be_an(Array)
  end

  it "raises Unavailable when 5xx/429 persist after retries" do
    stub = stub_dictionary("happy", status: 429, body: "")

    expect { client.entries("happy") }.to raise_error(described_class::Unavailable, /429/)
    expect(stub).to have_been_requested.times(Rails.configuration.x.dictionary_api.max_retries + 1)
  end

  it "does not block on a long Retry-After and leaves the retry to the background job" do
    stub = stub_request(:get, dictionary_url("happy")).to_return(status: 429, headers: { "Retry-After" => "300" })

    expect { client.entries("happy") }.to raise_error(described_class::Unavailable, /429/)
    expect(stub).to have_been_requested.once
  end

  it "raises Unavailable on timeouts" do
    stub_request(:get, dictionary_url("happy")).to_timeout

    expect { client.entries("happy") }.to raise_error(described_class::Unavailable)
  end

  it "raises InvalidResponse on malformed JSON" do
    stub_dictionary("happy", body: "<html>oops</html>")

    expect { client.entries("happy") }.to raise_error(described_class::InvalidResponse)
  end

  it "raises InvalidResponse when the payload is not an array" do
    stub_dictionary("happy", body: { message: "hello" })

    expect { client.entries("happy") }.to raise_error(described_class::InvalidResponse)
  end

  it "raises InvalidResponse on unexpected status codes" do
    stub_dictionary("happy", status: 400, body: "")

    expect { client.entries("happy") }.to raise_error(described_class::InvalidResponse)
  end
end
