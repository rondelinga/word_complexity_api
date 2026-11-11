# Scores a single word of a ComplexityJob. One job per word lets Sidekiq
# process words of the same request in parallel.
class ScoreWordJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :polynomially_longer, attempts: 3 do |job, error|
    job.fail_word!("processing_error", error)
  end

  retry_on Dictionary::Client::Unavailable, wait: :polynomially_longer, attempts: 6 do |job, error|
    job.fail_word!("dictionary_unavailable", error)
  end

  def perform(word_score_id)
    word_score = WordScore.includes(:complexity_job).find_by(id: word_score_id)
    return if word_score.nil? || !word_score.pending?

    word_score.complexity_job.mark_in_progress!

    stats = Dictionary::Lookup.new.call(word_score.word)
    word_score.complete!(stats:, score: ComplexityScore.calculate(stats))
  rescue Dictionary::Client::WordNotFound
    word_score.fail!("word_not_found")
  rescue ComplexityScore::NoDefinitions
    word_score.fail!("no_definitions")
  rescue Dictionary::Client::InvalidResponse => e
    Rails.logger.error("[ScoreWordJob] invalid dictionary response for word_score=#{word_score_id}: #{e.message}")
    word_score.fail!("invalid_dictionary_response")
  end

  def fail_word!(error_code, error)
    Rails.logger.error("[ScoreWordJob] giving up on word_score=#{arguments.first} after #{executions} attempts: #{error.class}: #{error.message}")
    WordScore.find_by(id: arguments.first)&.fail!(error_code)
  end
end
