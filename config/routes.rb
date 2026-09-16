Rails.application.routes.draw do
  root "feed#show"

  resource :session, only: %i[ new create destroy ]
  resources :passwords, param: :token, only: %i[ new create edit update ]

  # There is no public sign up: joining always goes through an invite code.
  get  "join/:code", to: "registrations#new", as: :join
  post "join/:code", to: "registrations#create"

  resources :invites, only: %i[ index create destroy ]

  resource :settings, only: %i[ show update ], controller: "settings"

  # Images are never served from a blob URL: see MediaController.
  get "media/:signed_id/:variant", to: "media#show", as: :media, format: false,
    constraints: { signed_id: %r{[^/]+}, variant: /thumb|feed|full/ }

  # Profiles read as handles: /@alice
  get "@:handle", to: "profiles#show", as: :profile, constraints: { handle: /[a-z0-9_]{2,32}/ }

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check
end
