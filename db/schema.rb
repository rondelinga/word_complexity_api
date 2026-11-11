# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_11_11_120100) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  create_table "complexity_jobs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "status", default: "pending", null: false
    t.integer "total_words", null: false
    t.integer "processed_words", default: 0, null: false
    t.datetime "started_at"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.check_constraint "processed_words >= 0 AND processed_words <= total_words", name: "complexity_jobs_progress_check"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying, 'in_progress'::character varying, 'completed'::character varying, 'failed'::character varying]::text[])", name: "complexity_jobs_status_check"
  end

  create_table "word_scores", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "complexity_job_id", null: false
    t.string "word", null: false
    t.integer "position", null: false
    t.string "status", default: "pending", null: false
    t.decimal "score", precision: 10, scale: 2
    t.integer "synonyms_count"
    t.integer "antonyms_count"
    t.integer "definitions_count"
    t.string "error_code"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["complexity_job_id", "position"], name: "index_word_scores_on_complexity_job_id_and_position"
    t.index ["complexity_job_id", "word"], name: "index_word_scores_on_complexity_job_id_and_word", unique: true
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying, 'completed'::character varying, 'failed'::character varying]::text[])", name: "word_scores_status_check"
  end

  add_foreign_key "word_scores", "complexity_jobs", on_delete: :cascade
end
