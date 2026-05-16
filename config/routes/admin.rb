constraints subdomain: "admin" do
  scope module: "admin", as: :admin do
    root to: redirect("/campaigns")

    resources :campaigns do
      resource :chaos_factor, only: [ :update ], controller: "chaos_factors"

      resources :player_characters

      resources :scenes do
        resource :closure, only: [ :create ], controller: "scene_closures"
        resource :audit, only: [ :show ], controller: "scene_audits"

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
