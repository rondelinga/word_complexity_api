class CreateWordScores < ActiveRecord::Migration[8.1]
  def change
    create_table :word_scores, id: :uuid do |t|
      t.references :complexity_job, type: :uuid, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.string :word, null: false
      t.integer :position, null: false
      t.string :status, null: false, default: "pending"
      t.decimal :score, precision: 10, scale: 2
      t.integer :synonyms_count
      t.integer :antonyms_count
      t.integer :definitions_count
      t.string :error_code
      t.timestamps
    end

    add_index :word_scores, [ :complexity_job_id, :word ], unique: true
    add_index :word_scores, [ :complexity_job_id, :position ]
    add_check_constraint :word_scores,
      "status IN ('pending', 'completed', 'failed')",
      name: "word_scores_status_check"
  end
end
