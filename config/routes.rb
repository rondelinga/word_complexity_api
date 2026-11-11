Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  scope format: false, defaults: { format: :json } do
    post "complexity-score", to: "complexity_scores#create", as: :complexity_scores
    get "complexity-score/:job_id", to: "complexity_scores#show", as: :complexity_score
  end
end
