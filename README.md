# Word Complexity Score API

An asynchronous Rails API that accepts a list of words and calculates a
"complexity score" for each one using the free
[Dictionary API](https://dictionaryapi.dev):

```
score = (synonyms + antonyms) / definitions
```

## Quick start (Docker Desktop)

Requirements: Docker Desktop (Docker Compose v2).

```bash
docker compose up --build
```

| Service   | URL / role                                              |
|-----------|---------------------------------------------------------|
| `web`     | API on http://localhost:3000 (creates/migrates the DB on boot) |
| `worker`  | Sidekiq, processes scoring jobs                         |
| `db`      | PostgreSQL 16                                           |
| `redis`   | Sidekiq queue + dictionary response cache               |
| `swagger` | Interactive API docs on http://localhost:8080           |

Ports can be changed with `WEB_PORT` / `SWAGGER_PORT`, for example
`WEB_PORT=3001 docker compose up`.

Stop with `docker compose down` (add `-v` to also delete the database and cache volumes).

## Usage

```bash
# 1. Submit words -> 202 Accepted
curl -s -X POST http://localhost:3000/complexity-score \
  -H 'Content-Type: application/json' \
  -d '["happy", "joyful", "sad", "angry"]'
# {"job_id":"9434445d-771f-4c12-944d-f1c02cf0ace2"}

# 2. Poll the job
curl -s http://localhost:3000/complexity-score/9434445d-771f-4c12-944d-f1c02cf0ace2
```

While processing:

```json
{ "job_id": "9434445d-…", "status": "in_progress", "progress": { "processed": 2, "total": 4 } }
```

When finished:

```json
{
  "job_id": "9434445d-…",
  "status": "completed",
  "progress": { "processed": 4, "total": 4 },
  "result": { "happy": 3.0, "joyful": 0.0, "sad": 1.8, "angry": 4.0 }
}
```

Words that could not be scored get `null` in `result` and are listed in `errors`:

```json
"result": { "happy": 3.0, "qwzxqv": null },
"errors": { "qwzxqv": "word_not_found" }
```

The full contract is in [`docs/openapi.yaml`](docs/openapi.yaml), which Swagger UI serves at http://localhost:8080.

### Endpoints

| Method | Path                         | Success | Errors |
|--------|------------------------------|---------|--------|
| POST   | `/complexity-score`          | `202` + `{ "job_id" }` + `Location` header | `400` malformed JSON, `422` invalid payload |
| GET    | `/complexity-score/:job_id`  | `200` job status / result | `404` unknown job |
| GET    | `/up`                        | `200` health check | |

### Job statuses

| Status        | Meaning |
|---------------|---------|
| `pending`     | Accepted, no word processed yet |
| `in_progress` | At least one word picked up by a worker |
| `completed`   | Every word processed and at least one scored |
| `failed`      | Every word processed and none could be scored |

### Word error codes

| Code                          | Meaning |
|-------------------------------|---------|
| `word_not_found`              | Dictionary returned 404 |
| `no_definitions`              | Entry exists but has no definitions (score would divide by zero) |
| `dictionary_unavailable`      | Timeouts / 429 / 5xx persisted after all retries |
| `invalid_dictionary_response` | Unexpected status code or malformed body |
| `processing_error`            | Unexpected internal error after retries |

Every error response uses the same shape:

```json
{ "error": { "code": "invalid_request", "message": "Request validation failed", "details": ["Element at index 1 must be a string"] } }
```

## How it works

```
POST /complexity-score
  ├─ validate + normalize words (trim, downcase, de-duplicate)
  ├─ INSERT complexity_jobs + one word_scores row per word (one transaction)
  └─ bulk-enqueue one ScoreWordJob per word (Sidekiq)  ──► 202 { job_id }

ScoreWordJob (runs in parallel across Sidekiq threads/processes)
  ├─ Dictionary::Lookup  ─► Redis cache ─► (miss) Dictionary::Client ─► dictionaryapi.dev
  ├─ Dictionary::WordStats  counts definitions / synonyms / antonyms
  ├─ ComplexityScore        (synonyms + antonyms) / definitions
  └─ WordScore#complete! / #fail!  ─► ComplexityJob#record_word_processed!
                                       (row lock; the last word finalizes the job)

GET /complexity-score/:job_id ─► ComplexityJobSerializer
```

### Design decisions

- **Asynchronous fan-out.** Each word is its own background job, so a request's
  words are fetched in parallel and throughput scales by adding Sidekiq threads
  or `worker` replicas (`docker compose up --scale worker=3`). The API only
  writes to the DB and enqueues, so it responds in milliseconds.
- **Consistent progress tracking.** A word's transition out of `pending` is a
  conditional `UPDATE … WHERE status = 'pending'`, so retries or duplicate
  deliveries can't count a word twice. The job counter is updated under a row
  lock, so concurrent workers can't race when finalizing the job. DB check
  constraints guard statuses and progress bounds.
- **Error handling and retries, in layers:**
  1. HTTP: timeouts (3s connect / 5s read) and up to 2 quick retries with
     jittered backoff for timeouts, 429 and 5xx. `Retry-After` is honoured only
     up to 2s, so a rate-limited request never blocks a worker thread for
     minutes; longer waits are handed over to the job-level retry.
  2. Job: `Dictionary::Client::Unavailable` is retried with polynomial backoff
     (6 attempts); then the word is marked `dictionary_unavailable`.
  3. Permanent errors (404, malformed responses, no definitions) fail the word
     immediately, without retrying.
  4. Any unexpected error is retried 3 times and then recorded as
     `processing_error`, so a job never hangs in `in_progress`.
  5. API: consistent JSON error bodies; unexpected exceptions return a generic 500.
- **Efficiency.**
  - Duplicate words in a request are scored once.
  - Dictionary results are cached in Redis for 24h; "not found" answers for 1h.
    Transient failures are never cached. Popular words cost one HTTP call
    across all jobs.
  - Word rows are bulk-inserted and jobs bulk-enqueued (`insert_all!`,
    `perform_all_later`).
  - Cache failures are logged and fall through to the API instead of failing the job.
- **Counting rule.** dictionaryapi.dev lists synonyms/antonyms both on each
  definition and on each meaning (part of speech). Both levels are counted
  across all entries, de-duplicated case-insensitively so the same synonym isn't
  counted twice. `definitions` is the total number of definitions across all
  entries. Scores are rounded to 2 decimals.
- **Input limits.** 1–100 words per request, ≤ 64 characters each; letters with
  inner spaces, hyphens or apostrophes (for example `ice cream`, `well-being`,
  `don't`).

### Project layout

```
app/controllers/complexity_scores_controller.rb  # endpoints
app/models/complexity_request.rb                 # payload parsing/validation
app/models/complexity_job.rb, word_score.rb      # persistence + state transitions
app/jobs/score_word_job.rb                       # per-word background job
app/services/dictionary/client.rb                # HTTP client + error mapping
app/services/dictionary/lookup.rb                # caching layer
app/services/dictionary/word_stats.rb            # response parsing / counting
app/services/complexity_score.rb                 # the formula
app/serializers/complexity_job_serializer.rb     # GET response shape
docs/openapi.yaml                                # API contract
spec/                                            # RSpec suite
```

## Tests and quality checks

The suite uses WebMock and never calls the real dictionary API.

```bash
docker compose up -d db redis
docker compose run --rm -e RAILS_ENV=test web bash -c "bin/rails db:prepare && bundle exec rspec"

# Lint and security checks
docker compose run --rm --no-deps web bin/rubocop
docker compose run --rm --no-deps web bin/brakeman --no-pager
docker compose run --rm --no-deps web bin/bundler-audit
```

## Configuration

All settings are environment variables with sensible defaults:

| Variable | Default | Purpose |
|----------|---------|---------|
| `DICTIONARY_API_URL` | `https://api.dictionaryapi.dev/api/v2/entries/en` | Dictionary endpoint |
| `DICTIONARY_API_OPEN_TIMEOUT` / `DICTIONARY_API_READ_TIMEOUT` | `3` / `5` s | HTTP timeouts |
| `DICTIONARY_API_MAX_RETRIES` / `DICTIONARY_API_RETRY_INTERVAL` | `2` / `0.3` s | In-request retries |
| `DICTIONARY_API_MAX_RETRY_INTERVAL` | `2` s | Longest in-request wait (incl. `Retry-After`) |
| `DICTIONARY_CACHE_TTL` / `DICTIONARY_NOT_FOUND_CACHE_TTL` | `86400` / `3600` s | Cache lifetimes |
| `MAX_WORDS_PER_REQUEST` / `MAX_WORD_LENGTH` | `100` / `64` | Input limits |
| `SIDEKIQ_CONCURRENCY` | `10` | Worker threads |
| `DATABASE_HOST`, `DATABASE_USER`, `DATABASE_PASSWORD` | `localhost`, `postgres`, `postgres` | PostgreSQL |
| `REDIS_URL` / `REDIS_CACHE_URL` | `redis://localhost:6379/0` / `/1` | Queue / cache |

## Stack

Ruby 3.4, Rails 8.1 (API-only), PostgreSQL 16, Redis 7, Sidekiq 7, Faraday,
RSpec + WebMock.
