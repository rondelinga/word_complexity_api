class ApplicationController < ActionController::API
  wrap_parameters false

  rescue_from StandardError do |e|
    Rails.logger.error("#{e.class}: #{e.message}\n#{Array(e.backtrace).first(10).join("\n")}")
    render_error(:internal_server_error, "internal_error", "Something went wrong")
  end

  rescue_from ActiveRecord::RecordNotFound do
    render_error(:not_found, "not_found", "Resource not found")
  end

  rescue_from ActionDispatch::Http::Parameters::ParseError do |e|
    render_error(:bad_request, "malformed_json", "Request body is not valid JSON: #{e.message}")
  end

  private

  def render_error(status, code, message, details: nil)
    error = { code:, message: }
    error[:details] = details if details.present?
    render json: { error: }, status:
  end
end
