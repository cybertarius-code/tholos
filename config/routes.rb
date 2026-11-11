Rails.application.routes.draw do
  mount Lookbook::Engine, at: "/lookbook" if Rails.env.development?
  root "homes#index"
  get "dashboard/index", to: "dashboard#index", as: :user_home
  resources :homes, only: [ :index, :show ]
  resource :session
  resources :passwords, param: :token
  get "up" => "rails/health#show", as: :rails_health_check
end
