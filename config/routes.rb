Rails.application.routes.draw do
  root "feed#show"

  resource :session, only: %i[ new create destroy ]
  resources :passwords, param: :token, only: %i[ new create edit update ]

  # There is no public sign up: joining always goes through an invite code.
  get  "join/:code", to: "registrations#new", as: :join
  post "join/:code", to: "registrations#create"

  resources :invites, only: %i[ index create destroy ]

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check
end
