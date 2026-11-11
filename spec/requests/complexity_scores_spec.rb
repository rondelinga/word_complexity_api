require "rails_helper"

RSpec.describe "Complexity score API" do
  let(:headers) { { "Content-Type" => "application/json", "Accept" => "application/json" } }

  def post_words(body)
    post("/complexity-score", params: body.is_a?(String) ? body : body.to_json, headers:)
  end

  def json
    response.parsed_body
  end

  describe "POST /complexity-score" do
    it "accepts the words and returns a job id" do
      expect { post_words(%w[happy joyful sad angry]) }
        .to change(ComplexityJob, :count).by(1)
        .and have_enqueued_job(ScoreWordJob).exactly(4).times

      expect(response).to have_http_status(:accepted)
      expect(json.keys).to eq([ "job_id" ])
      expect(response.headers["Location"]).to end_with("/complexity-score/#{json['job_id']}")
    end

    it "de-duplicates words" do
      post_words(%w[happy Happy HAPPY])

      expect(ComplexityJob.find(json["job_id"]).total_words).to eq(1)
    end

    it "returns 400 for malformed JSON" do
      post_words("[happy")

      expect(response).to have_http_status(:bad_request)
      expect(json.dig("error", "code")).to eq("malformed_json")
    end

    it "returns 422 with details for invalid payloads" do
      post_words([ "happy", 1 ])

      expect(response).to have_http_status(:unprocessable_content)
      expect(json["error"]).to include(
        "code" => "invalid_request",
        "details" => [ "Element at index 1 must be a string" ]
      )
    end

    it "returns 422 for a non-array body" do
      post_words({ words: [ "happy" ] })

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "GET /complexity-score/:job_id" do
    it "returns pending status with progress before processing starts" do
      post_words(%w[happy sad])
      get("/complexity-score/#{json['job_id']}", headers:)

      expect(response).to have_http_status(:ok)
      expect(json).to include("status" => "pending", "progress" => { "processed" => 0, "total" => 2 })
      expect(json).not_to have_key("result")
    end

    it "returns in_progress while some words are still being processed" do
      stub_dictionary("happy", fixture: "happy")
      post_words(%w[happy sad])
      job = ComplexityJob.find(json["job_id"])
      ScoreWordJob.perform_now(job.word_scores.first.id)

      get("/complexity-score/#{job.id}", headers:)

      expect(json).to include("status" => "in_progress", "progress" => { "processed" => 1, "total" => 2 })
    end

    it "returns the result once the job is completed (end to end)" do
      stub_dictionary("happy", fixture: "happy")
      stub_dictionary("sad", body: dictionary_entry("sad", [
        meaning(definitions: [ definition(synonyms: %w[unhappy]), definition ], antonyms: %w[happy glad])
      ]))
      stub_dictionary_not_found("qwzxqv")

      perform_enqueued_jobs { post_words(%w[happy sad qwzxqv]) }
      get("/complexity-score/#{json['job_id']}", headers:)

      expect(response).to have_http_status(:ok)
      expect(json).to include(
        "status" => "completed",
        "result" => { "happy" => 1.5, "sad" => 1.5, "qwzxqv" => nil },
        "errors" => { "qwzxqv" => "word_not_found" },
        "progress" => { "processed" => 3, "total" => 3 }
      )
      expect(json["result"].keys).to eq(%w[happy sad qwzxqv])
    end

    it "omits errors when every word succeeded" do
      stub_dictionary("happy", fixture: "happy")

      perform_enqueued_jobs { post_words(%w[happy]) }
      get("/complexity-score/#{json['job_id']}", headers:)

      expect(json).to include("status" => "completed", "result" => { "happy" => 1.5 })
      expect(json).not_to have_key("errors")
    end

    it "returns 404 for unknown jobs" do
      get("/complexity-score/#{SecureRandom.uuid}", headers:)

      expect(response).to have_http_status(:not_found)
      expect(json.dig("error", "code")).to eq("job_not_found")
    end

    it "returns 404 for malformed job ids" do
      get("/complexity-score/abc123", headers:)

      expect(response).to have_http_status(:not_found)
    end
  end
end
