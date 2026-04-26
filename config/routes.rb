Rails.application.routes.draw do
  resources :available_models do
    collection { post :sync }
  end
  resources :jobs
  resources :servers
  post "trigger/get_remote_jobs", to: "triggers#get_remote_jobs", as: :trigger_get_remote_jobs
  post "trigger/run_llm",         to: "triggers#run_llm",         as: :trigger_run_llm
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "jobs#index"
end
