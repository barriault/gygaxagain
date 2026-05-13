constraints subdomain: "" do
  devise_for :users, skip: [:registrations]

  # Play home root is added in Task 10.
end
