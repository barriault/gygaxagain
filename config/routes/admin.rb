constraints subdomain: "admin" do
  scope module: "admin" do
    root "dashboard#show", as: :admin_root
    get "/dashboard", to: "dashboard#show", as: :admin_dashboard
  end
end
