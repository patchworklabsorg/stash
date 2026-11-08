Rails.application.routes.draw do
  # Health checks (public endpoint)
  mount OkComputer::Engine, at: '/health' if defined?(OkComputer)
  namespace :admin do
    root to: 'application#index'

    # Blazer BI Dashboard (admin or above)
    mount Blazer::Engine, at: 'blazer', constraints: AdminConstraint.new(:blazer?) if defined?(Blazer)

    # Flipper Feature Flags (super_admin or above)
    mount Flipper::UI.app(Flipper), at: 'flipper', constraints: AdminConstraint.new(:flipper?) if defined?(Flipper)

    # Rails Performance Dashboard (admin or above)
    mount RailsPerformance::Engine, at: 'performance', constraints: AdminConstraint.new(:rails_performance?) if defined?(RailsPerformance)

    # GoodJob Dashboard (admin or above)
    mount GoodJob::Engine, at: 'jobs', constraints: AdminConstraint.new(:jobs?) if defined?(GoodJob)

    # Console Audits (super_admin or above)
    mount Audits1984::Engine, at: 'console_audits', constraints: AdminConstraint.new(:console_audits?) if defined?(Audits1984)

    # PgHero PostgreSQL Dashboard (admin or above)
    mount PgHero::Engine, at: 'pghero', constraints: AdminConstraint.new(:pghero?) if defined?(PgHero)

    resources :users
  end
  # Authentication
  get 'sign_in', to: 'sessions#new'
  post 'sign_in', to: 'sessions#create'
  delete 'sign_out', to: 'sessions#destroy'
  get 'sign_up', to: 'registrations#new'
  post 'sign_up', to: 'registrations#create'
  if Rails.env.development?
    mount LetterOpenerWeb::Engine, at: '/letter_opener'
  end
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
end
