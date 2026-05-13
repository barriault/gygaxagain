constraints subdomain: "" do
  devise_for :users, skip: [:registrations], controllers: { sessions: "users/sessions" }

  root "play/home#show"
end
