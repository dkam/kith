Rails.application.routes.draw do
  root "feed#show"

  resource :session, only: %i[ new create destroy ]
  resources :passwords, param: :token, only: %i[ new create edit update ]

  # The first member can't be invited, so while the instance is empty the
  # server's console issues the credential instead. 404s afterwards: see Setup.
  get  "setup", to: "setup#new"
  post "setup", to: "setup#create"

  # There is no public sign up: joining always goes through an invite code.
  get  "join/:code", to: "registrations#new", as: :join
  post "join/:code", to: "registrations#create"

  resources :invites, only: %i[ index create destroy ]

  resource :settings, only: %i[ show update ], controller: "settings"
  delete "settings/avatar", to: "settings#destroy_avatar", as: :settings_avatar

  resources :posts, except: :index do
    resources :comments, only: :create
  end
  resources :comments, only: :destroy

  resources :feed_items, only: :update do
    collection { post :read_all }
  end

  resources :notifications, only: %i[ index update ] do
    collection { post :read_all }
  end

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

  # A photograph the editor has uploaded but no post has claimed yet. The
  # template Lexxy fills in wants a filename on the end; nothing reads it.
  get "media/pending/:signed_id(/:filename)", to: "media#pending", as: :pending_media, format: false,
    constraints: { signed_id: %r{[^/]+}, filename: %r{[^/]+} }

  # Profiles read as handles: /@alice
  get "@:handle", to: "profiles#show", as: :profile, constraints: { handle: /[A-Za-z0-9_]{2,32}/ }

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check
end
