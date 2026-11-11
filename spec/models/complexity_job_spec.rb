require "rails_helper"

RSpec.describe ComplexityJob do
  describe ".enqueue!" do
    it "creates the job with pending word scores and enqueues one ScoreWordJob per word" do
      job = nil

      expect { job = described_class.enqueue!(%w[happy sad angry]) }
        .to have_enqueued_job(ScoreWordJob).exactly(3).times

      expect(job).to be_pending
      expect(job.total_words).to eq(3)
      expect(job.word_scores.map(&:word)).to eq(%w[happy sad angry])
      expect(job.word_scores).to all(be_pending)
    end
  end

  describe "#record_word_processed!" do
    let(:job) { described_class.enqueue!(%w[happy sad]) }

    it "moves to in_progress until all words are processed" do
      job.word_scores.first.update!(status: "completed", score: 1)
      job.record_word_processed!

      expect(job.reload).to be_in_progress
      expect(job.processed_words).to eq(1)
      expect(job.completed_at).to be_nil
    end

    it "completes when the last word is processed and at least one succeeded" do
      job.word_scores.first.update!(status: "completed", score: 1)
      job.word_scores.last.update!(status: "failed", error_code: "word_not_found")
      2.times { job.record_word_processed! }

      expect(job.reload).to be_completed
      expect(job.completed_at).to be_present
    end

    it "fails when every word failed" do
      job.word_scores.update_all(status: "failed", error_code: "word_not_found")
      2.times { job.record_word_processed! }

      expect(job.reload).to be_failed
    end
  end
end
