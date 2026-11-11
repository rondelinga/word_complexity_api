class ComplexityScoresController < ApplicationController
  rescue_from ComplexityRequest::MalformedJson do |e|
    render_error(:bad_request, "malformed_json", "Request body is not valid JSON: #{e.message}")
  end

  # POST /complexity-score
  def create
    complexity_request = ComplexityRequest.from_json(request.raw_post)

    unless complexity_request.valid?
      return render_error(:unprocessable_content, "invalid_request", "Request validation failed",
        details: complexity_request.errors.full_messages)
    end

    job = ComplexityJob.enqueue!(complexity_request.words)
    response.headers["Location"] = complexity_score_url(job_id: job.id)
    render json: { job_id: job.id }, status: :accepted
  end

  # GET /complexity-score/:job_id
  def show
    job = ComplexityJob.find_by(id: params[:job_id])
    return render_error(:not_found, "job_not_found", "Job #{params[:job_id]} not found") unless job

    render json: ComplexityJobSerializer.new(job)
  end
end
