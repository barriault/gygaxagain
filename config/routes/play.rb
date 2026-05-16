constraints subdomain: "" do
  devise_for :users, skip: [ :registrations ], controllers: { sessions: "users/sessions" }

  root "play/home#show"

  scope module: "play" do
    resources :campaigns, only: [ :index ] do
      member { get :play }

      resources :scenes, only: [] do
        member { get :play }

        resources :dice_rolls,       only: [ :create ]
        resources :pc_declarations,  only: [ :create ]
        resource  :reset,            only: [ :create ], controller: "scene_resets"
      end
    end
  end
end
