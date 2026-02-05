Rails.application.routes.draw do
  root "admin/students#index"
  namespace :admin do
    resources :klasses do
      resources :courses do
        member do
          put :start, to: "courses#start"
        end
        resources :attendances do
          member do
            put :mark
          end
        end
      end
    end
    resources :teachers
    resources :students
    resources :users
    resources :schools do
      resources :semesters do
        member do
          get :switch_thread_semester
        end
      end
      resources :campuses do
        member do
          get :switch_thread_campuse
        end
      end
      resources :semesters
    end
  end
  resource :session
  resources :passwords, param: :token
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
