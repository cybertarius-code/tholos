Rails.application.routes.draw do
  mount Lookbook::Engine, at: "/lookbook" if Rails.env.development?
  root "homes#index"
  get "dashboard", to: "dashboard#show", as: :dashboard
  get "presupuesto", to: "coming_soon#show", defaults: { section: "budget" }, as: :budget
  get "metas", to: "coming_soon#show", defaults: { section: "goals" }, as: :goals
  get "patrimonio", to: "coming_soon#show", defaults: { section: "net_worth" }, as: :net_worth
  get "ajustes", to: "coming_soon#show", defaults: { section: "settings" }, as: :settings
  resources :accounts, path: "cuentas", path_names: { new: "nueva", edit: "editar" } do
    resource :closure, only: [ :create, :destroy ], path: "cierre", module: :accounts
    resource :adjustment, only: [ :new, :create ], path: "ajuste", path_names: { new: "nuevo" }, module: :accounts
    resources :imports, only: [ :new, :create, :show ], path: "importaciones", path_names: { new: "nueva" }
  end
  resources :transactions, path: "movimientos", except: :show,
    path_names: { new: "nuevo", edit: "editar" } do
    resource :receipt, only: [ :show, :destroy ], path: "recibo", module: :transactions
    resource :duplicate, only: :new, path: "duplicar", path_names: { new: "nuevo" }, module: :transactions
  end
  resources :transfers, path: "transferencias", only: %i[ new create edit update destroy ],
    path_names: { new: "nueva", edit: "editar" }
  resources :import_rows, only: :update, path: "filas-importadas"
  resources :imports, only: [] do
    resource :commit, only: :create, path: "confirmar", module: :imports
  end
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
