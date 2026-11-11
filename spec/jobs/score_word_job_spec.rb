require "rails_helper"

RSpec.describe ScoreWordJob do
  let!(:job) { ComplexityJob.enqueue!(%w[happy]) }
  let(:word_score) { job.word_scores.first }

  before { clear_enqueued_jobs }

  it "scores the word and completes the job" do
    stub_dictionary("happy", fixture: "happy")

    described_class.perform_now(word_score.id)

    expect(word_score.reload).to have_attributes(
      status: "completed", score: BigDecimal("1.5"),
      synonyms_count: 4, antonyms_count: 2, definitions_count: 4
    )
    expect(job.reload).to have_attributes(status: "completed", processed_words: 1)
  end

  it "marks the word as not found" do
    stub_dictionary_not_found("happy")

    described_class.perform_now(word_score.id)

    expect(word_score.reload).to have_attributes(status: "failed", error_code: "word_not_found", score: nil)
    expect(job.reload).to be_failed
  end

  it "marks words without definitions" do
    stub_dictionary("happy", body: dictionary_entry("happy", []))

    described_class.perform_now(word_score.id)

    expect(word_score.reload.error_code).to eq("no_definitions")
  end

  it "marks invalid dictionary responses without retrying" do
    stub_dictionary("happy", body: "not json")

    described_class.perform_now(word_score.id)

    expect(word_score.reload.error_code).to eq("invalid_dictionary_response")
    expect(described_class).not_to have_been_enqueued
  end

  it "re-enqueues itself when the dictionary is unavailable" do
    stub_dictionary("happy", status: 503, body: "")

    described_class.perform_now(word_score.id)

    expect(described_class).to have_been_enqueued.with(word_score.id)
    expect(word_score.reload).to be_pending
    expect(job.reload).to be_in_progress
  end

  it "gives up after exhausting retries and records the failure" do
    stub_dictionary("happy", status: 503, body: "")

    perform_enqueued_jobs do
      described_class.perform_later(word_score.id)
    end

    expect(word_score.reload).to have_attributes(status: "failed", error_code: "dictionary_unavailable")
    expect(job.reload).to have_attributes(status: "failed", processed_words: 1)
  end

  it "is idempotent when a word is processed twice" do
    stub_dictionary("happy", fixture: "happy")

    2.times { described_class.perform_now(word_score.id) }

    expect(job.reload.processed_words).to eq(1)
  end

  it "ignores word scores that no longer exist" do
    expect { described_class.perform_now(SecureRandom.uuid) }.not_to raise_error
  end
end
