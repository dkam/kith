Rails.application.routes.draw do
  root "feed#show"

  resource :session, only: %i[ new create destroy ]
  resources :passwords, param: :token, only: %i[ new create edit update ]

  # There is no public sign up: joining always goes through an invite code.
  get  "join/:code", to: "registrations#new", as: :join
  post "join/:code", to: "registrations#create"

  resources :invites, only: %i[ index create destroy ]

  resource :settings, only: %i[ show update ], controller: "settings"

  resources :posts, except: :index

  # Following is asked for, and answered, one edge at a time.
  get "follows", to: "follow_requests#index", as: :follows
  post "actors/:handle/follow", to: "follows#create", as: :follow_actor, constraints: { handle: /[A-Za-z0-9_]{2,32}/ }
  resources :follows, only: :destroy do
    member do
      post :accept
      post :reject
    end
  end

  # Images are never served from a blob URL: see MediaController.
  get "media/:signed_id/:variant", to: "media#show", as: :media, format: false,
    constraints: { signed_id: %r{[^/]+}, variant: /thumb|feed|full/ }

  # Profiles read as handles: /@alice
  get "@:handle", to: "profiles#show", as: :profile, constraints: { handle: /[A-Za-z0-9_]{2,32}/ }

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check
end
