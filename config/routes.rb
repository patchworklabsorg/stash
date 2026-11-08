Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # "/" sends you to sign-in, or to the archive list when you are signed in.
  root "home#show"

  get "sign_in" => "sessions#new"
  post "auth/weave" => "sessions#create", as: :auth_weave
  get "auth/callback" => "sessions#callback"
  delete "sign_out" => "sessions#destroy"

  # The dev-only sign-in. These routes exist only in development and test. The app refuses to
  # boot in production and staging with STASH_AUTH_MODE=dev. Outside dev mode the controller
  # answers 404.
  if Rails.env.local?
    get "dev/sign_in" => "dev_sessions#new"
    post "dev/sign_in" => "dev_sessions#create"
  end

  # Archives by public id (arc_...). Archive#to_param gives the public id.
  resources :archives, only: %i[index show new create destroy] do
    post :rerun, on: :member
  end

  # One artifact's file, by public id (art_...), through a signed storage URL.
  resources :artifacts, only: :show

  # The archive API for patch apps, such as Krater. Bearer tokens from Weave, no session.
  namespace :api do
    namespace :v1 do
      resources :archives, only: %i[index show create]
    end
  end

  # The GoodJob dashboard, for admins. The constraint reads the session cookie.
  mount GoodJob::Engine => "admin/jobs", constraints: AdminConstraint.new
end
