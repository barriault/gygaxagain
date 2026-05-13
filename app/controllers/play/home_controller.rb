module Play
  class HomeController < ::ApplicationController
    # Public landing page during alpha — flip to authenticated once we have
    # a proper play-surface sign-in landing.
    skip_before_action :authenticate_user!

    def show
      render Play::HomeComponent.new
    end
  end
end
