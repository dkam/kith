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

  resource :settings, only: %i[ show update ], controller: "settings" do
    # A member's agent endpoints. `update` is the reset button: the old token
    # stops working the moment it returns, which is the point of it.
    resources :mcp_tokens, only: %i[ create update destroy ]
  end

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

  # One member's agent endpoint. The token rides in the query string because
  # that is the only place every MCP client can carry it — `?token=` is also
  # what Rails already filters out of the logs — with an Authorization: Bearer
  # header accepted for clients that can send one. GET is the stream a
  # streamable-HTTP client may ask for; Kith has nothing to say unprompted.
  post "mcp", to: "mcp#create", as: :mcp
  get  "mcp", to: "mcp#show"

  # The installable app. Both are rendered from app/views/pwa so the manifest
  # is built from the same tokens the stylesheet is, and both answer signed
  # out: a phone fetches them before anybody has signed in.
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Every Kith is somebody else's, so a phone app has to be told which one it
  # is talking to — and then has to check. NodeInfo is the answer the rest of
  # the fediverse already gives to that question, which makes this a federation
  # seam rather than a phone one: whatever else learns to read Kith later will
  # look here first.
  get ".well-known/nodeinfo", to: "node_info#index", as: :nodeinfo_index, defaults: { format: :json }
  get "nodeinfo/2.1", to: "node_info#show", as: :nodeinfo, defaults: { format: :json }

  # The phone apps' navigation rules. The shells fetch these at launch, so
  # which screen is a modal and which pushes can change without a new build.
  #
  # The version is in the name because a build that has shipped keeps asking
  # for the shape it was written against: ios_v1 may gain rules, but it may
  # never change what one of them means. When it needs to, that is ios_v2 and
  # a new build. See app/views/configurations.
  get "configurations/:name", to: "configurations#show", as: :hotwire_configuration,
    constraints: { name: /(ios|android)_v1/ }, defaults: { format: :json }

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check
end
