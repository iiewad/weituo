Rails.application.routes.draw do
  root "admin/dashboards#index"
  namespace :admin do
    get "guide", to: "guides#show", as: :guide
    post "guide/complete", to: "guides#complete", as: :complete_guide

    resources :semester_klasses do
      member do
        get :export_attendance
        post :reserve
      end
      collection do
        get :statement
        get :copy
        post :copy_create
        get :export_attendances
        get :export_statement
        patch :update_reserve_setting
      end
      resources :klass_students do
        member do
          put :restore
          put :reinstate
        end
        collection do
          delete :remove_batch
        end
      end
      resources :courses do
        member do
          put :start, to: "courses#start"
        end
        collection do
          put :start_through, to: "courses#start_through"
        end
        resources :attendances do
          member do
            put :mark
            put :transfer
          end
        end
      end
    end
    resources :teachers, only: [ :index, :create, :update ] do
      member do
        patch :archive
        patch :restore
      end
      collection do
        post :import
      end
    end
    resources :reservations, only: [ :index, :update, :destroy ] do
      collection do
        post :batch_enroll
      end
    end
    resources :day_schools, only: [ :index, :create, :update, :destroy ] do
      collection do
        post :import
      end
    end
    resources :students, only: [ :index, :create, :update ] do
      member do
        delete :destroy
        patch :restore
      end
      collection do
        post :promote
        post :import
        post :quick_create
        get :template
        get :options
      end
    end
    resources :referrals, only: [ :index ] do
      collection { get :export }
    end
    resources :grade_reports, only: [ :index ] do
      collection { get :export }
    end
    resources :grade_subjects, only: [ :index ] do
      collection do
        put :sync
      end
    end
    resources :grades, only: [ :create, :update, :destroy ]
    resources :subjects, only: [ :create, :update, :destroy ]
    resources :users, only: [ :index, :create, :update ]
    resources :semesters, only: [ :index, :create, :update, :destroy ] do
      member do
        get :switch_thread_semester
      end
    end
    resources :schools, only: [ :index, :update ] do
      resources :campuses do
        member do
          get :switch_thread_campuse
        end
      end
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
