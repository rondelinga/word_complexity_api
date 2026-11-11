class WordScore < ApplicationRecord
  STATUSES = %w[pending completed failed].freeze

  belongs_to :complexity_job, inverse_of: :word_scores

  enum :status, STATUSES.index_by(&:itself), validate: true

  validates :word, presence: true

  def complete!(stats:, score:)
    finish!(
      status: "completed",
      score:,
      synonyms_count: stats.synonyms,
      antonyms_count: stats.antonyms,
      definitions_count: stats.definitions
    )
  end

  def fail!(error_code)
    finish!(status: "failed", error_code:)
  end

  private

  def finish!(attributes)
    transaction do
      transitioned = self.class.where(id:, status: "pending").update_all(attributes.merge(updated_at: Time.current))
      next false if transitioned.zero?

      complexity_job.record_word_processed!
      true
    end
  end
end
