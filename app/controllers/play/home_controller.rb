module Play
  class HomeController < ::ApplicationController
    def show
      render Play::HomeComponent.new
    end
  end
end
