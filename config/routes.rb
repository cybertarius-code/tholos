Rails.application.routes.draw do
  mount Lookbook::Engine, at: "/lookbook" if Rails.env.development?
  root "homes#index"
  get "dashboard", to: "dashboard#show", as: :dashboard
  # SPK-0007: prototipo de gráficos, solo en desarrollo (la rama del spike no se mezcla)
  get "spike/graficos", to: "spike_charts#show", as: :spike_charts if Rails.env.development?
  get "presupuesto", to: "coming_soon#show", defaults: { section: "budget" }, as: :budget
  get "metas", to: "coming_soon#show", defaults: { section: "goals" }, as: :goals
  get "patrimonio", to: "coming_soon#show", defaults: { section: "net_worth" }, as: :net_worth
  get "ajustes", to: "coming_soon#show", defaults: { section: "settings" }, as: :settings
  resources :accounts, path: "cuentas", path_names: { new: "nueva", edit: "editar" } do
    resource :closure, only: [ :create, :destroy ], path: "cierre", module: :accounts
  end
  resources :transactions, path: "movimientos", except: :show,
    path_names: { new: "nuevo", edit: "editar" }
  resources :transfers, path: "transferencias", only: %i[ new create edit update destroy ],
    path_names: { new: "nueva", edit: "editar" }
  resources :categories, path: "ajustes/categorias", except: :show, path_names: { new: "nueva", edit: "editar" } do
    scope module: :categories do
      resource :archive, only: [ :create, :destroy ], path: "archivo"
      resource :position, only: :update, path: "posicion"
    end
  end
  resources :homes, only: [ :index, :show ]
  resource :session
  resources :passwords, param: :token

  namespace :settings do
    resource :password, only: [ :edit, :update ]
    resources :sessions, only: [ :index, :destroy ]
  end
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
end
