constraints subdomain: "" do
  devise_for :users, skip: [:registrations]

  root "play/home#show"
end
