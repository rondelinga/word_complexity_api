class ComplexityJob < ApplicationRecord
  STATUSES = %w[pending in_progress completed failed].freeze
  FINISHED_STATUSES = %w[completed failed].freeze

  has_many :word_scores, -> { order(:position) }, dependent: :delete_all, inverse_of: :complexity_job

  enum :status, STATUSES.index_by(&:itself), validate: true

  validates :total_words, numericality: { only_integer: true, greater_than: 0 }

  def self.enqueue!(words)
    job = transaction do
      created = create!(total_words: words.size)
      now = Time.current
      WordScore.insert_all!(
        words.each_with_index.map do |word, position|
          { complexity_job_id: created.id, word:, position:, status: "pending", created_at: now, updated_at: now }
        end
      )
      created
    end

    ActiveJob.perform_all_later(job.word_scores.ids.map { |id| ScoreWordJob.new(id) })
    job
  end

  def finished?
    FINISHED_STATUSES.include?(status)
  end

  def mark_in_progress!
    self.class.where(id:, status: "pending").update_all(status: "in_progress", started_at: Time.current, updated_at: Time.current)
  end

  def record_word_processed!
    with_lock do
      self.processed_words += 1
      self.started_at ||= Time.current

      if processed_words >= total_words
        self.status = word_scores.completed.exists? ? "completed" : "failed"
        self.completed_at = Time.current
      else
        self.status = "in_progress"
      end

      save!
    end
  end
end
