Rails.application.routes.draw do
  mount Lookbook::Engine, at: "/lookbook" if Rails.env.development?
  root "homes#index"
  get "dashboard", to: "dashboard#show", as: :dashboard
  get "movimientos", to: "coming_soon#show", defaults: { section: "movements" }, as: :movements
  get "cuentas", to: "coming_soon#show", defaults: { section: "accounts" }, as: :accounts
  get "presupuesto", to: "coming_soon#show", defaults: { section: "budget" }, as: :budget
  get "metas", to: "coming_soon#show", defaults: { section: "goals" }, as: :goals
  get "patrimonio", to: "coming_soon#show", defaults: { section: "net_worth" }, as: :net_worth
  get "ajustes", to: "coming_soon#show", defaults: { section: "settings" }, as: :settings
  resources :homes, only: [ :index, :show ]
  resource :session
  resources :passwords, param: :token
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
end
