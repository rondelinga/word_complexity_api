module DictionaryHelpers
  def dictionary_url(word)
    "#{Rails.configuration.x.dictionary_api.base_url}/#{ERB::Util.url_encode(word)}"
  end

  def dictionary_fixture(name)
    Rails.root.join("spec/fixtures/dictionary/#{name}.json").read
  end

  def stub_dictionary(word, body: nil, status: 200, fixture: nil)
    body = dictionary_fixture(fixture) if fixture
    body = body.to_json unless body.nil? || body.is_a?(String)
    stub_request(:get, dictionary_url(word))
      .to_return(status:, body: body.to_s, headers: { "Content-Type" => "application/json" })
  end

  def stub_dictionary_not_found(word)
    stub_dictionary(word, status: 404, body: { title: "No Definitions Found" })
  end

  # Builds a minimal dictionary payload with the given meanings.
  def dictionary_entry(word, meanings)
    [ { "word" => word, "meanings" => meanings } ]
  end

  def meaning(definitions:, synonyms: [], antonyms: [])
    { "partOfSpeech" => "adjective", "definitions" => definitions, "synonyms" => synonyms, "antonyms" => antonyms }
  end

  def definition(text = "a definition", synonyms: [], antonyms: [])
    { "definition" => text, "synonyms" => synonyms, "antonyms" => antonyms }
  end
end
