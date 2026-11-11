class CreateComplexityJobs < ActiveRecord::Migration[8.1]
  def change
    enable_extension "pgcrypto"

    create_table :complexity_jobs, id: :uuid do |t|
      t.string :status, null: false, default: "pending"
      t.integer :total_words, null: false
      t.integer :processed_words, null: false, default: 0
      t.datetime :started_at
      t.datetime :completed_at
      t.timestamps
    end

    add_check_constraint :complexity_jobs,
      "status IN ('pending', 'in_progress', 'completed', 'failed')",
      name: "complexity_jobs_status_check"
    add_check_constraint :complexity_jobs,
      "processed_words >= 0 AND processed_words <= total_words",
      name: "complexity_jobs_progress_check"
  end
end
