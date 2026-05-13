Rails.application.routes.draw do
  draw(:play)
  draw(:admin)

  constraints subdomain: "www" do
    get "(*any)", to: redirect(status: 301) { |_params, req|
      "#{req.protocol}#{req.host.sub(/^www\./, '')}#{req.fullpath}"
    }
  end

  get "up" => "rails/health#show", as: :rails_health_check

  if Rails.env.development?
    mount Lookbook::Engine, at: "/lookbook"
  end
end
