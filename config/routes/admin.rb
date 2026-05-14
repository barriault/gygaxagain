constraints subdomain: "admin" do
  scope module: "admin", as: :admin do
    root to: redirect("/campaigns")

    resources :campaigns do
      resource :chaos_factor, only: [ :update ], controller: "chaos_factors"

      resources :scenes do
        member do
          post :move_up
          post :move_down
        end
      end
    end

    namespace :diagnostics do
      resource :llm, only: [ :show, :create ], controller: "llm"
    end
  end
end
