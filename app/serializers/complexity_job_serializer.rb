class ComplexityJobSerializer
  def initialize(job)
    @job = job
  end

  def as_json(*)
    payload = {
      job_id: @job.id,
      status: @job.status,
      progress: { processed: @job.processed_words, total: @job.total_words }
    }
    return payload unless @job.finished?

    scores = @job.word_scores.to_a
    payload[:result] = scores.to_h { |s| [ s.word, s.score&.to_f ] }

    errors = scores.select(&:failed?).to_h { |s| [ s.word, s.error_code ] }
    payload[:errors] = errors if errors.any?
    payload
  end
end
