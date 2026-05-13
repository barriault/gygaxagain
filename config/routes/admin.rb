constraints subdomain: "admin" do
  scope module: "admin", as: :admin do
    root "dashboard#show"
    get "/dashboard", to: "dashboard#show", as: :dashboard

    resources :campaigns, except: [:show]
  end
end
